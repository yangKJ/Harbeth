//
//  GPUHistogram.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal
#if canImport(MetalPerformanceShaders)
import MetalPerformanceShaders
import simd

enum GPUHistogramSupport {

    static func makeHistogram(from texture: MTLTexture,
                              channel: TextureHistogramChannel,
                              bins: Int) -> TextureHistogram? {
        makeHistogramArtifacts(from: texture, channel: channel, bins: bins).histogram
    }

    static func makeRenderedHistogramAttachment(from texture: MTLTexture,
                                                channel: TextureHistogramChannel,
                                                bins: Int,
                                                height: Int) -> RenderedHistogramAttachment? {
        let artifacts = makeHistogramArtifacts(from: texture, channel: channel, bins: bins)
        guard let histogram = artifacts.histogram,
              let histogramBuffer = artifacts.buffer,
              let previewTexture = makePreviewTexture(
                device: artifacts.texture.device,
                histogram: histogram,
                histogramBuffer: histogramBuffer,
                resolvedChannel: artifacts.resolvedChannel,
                height: height
              ) else {
            return nil
        }
        return RenderedHistogramAttachment(
            histogram: histogram,
            attachment: RenderedAttachment(
                index: 1,
                semantic: .histogram,
                texture: previewTexture,
                debugPolicy: RenderOutputAttachmentContract.histogram(index: 1, pixelFormat: .rgba8Unorm).debugPolicy
            )
        )
    }

    private static func makeHistogramArtifacts(from texture: MTLTexture,
                                               channel: TextureHistogramChannel,
                                               bins: Int) -> HistogramArtifacts {
        let clampedBins = max(1, bins)
        let source: HistogramSource
        switch channel {
        case .luminance:
            guard let grayscale = try? HarbethIO(element: texture, filter: C7Grayed())
                .renderTexture(profile: .readbackQuality) else {
                return HistogramArtifacts(texture: texture, histogram: nil, buffer: nil, resolvedChannel: .red)
            }
            source = HistogramSource(texture: grayscale, resolvedChannel: .red)
        case .red, .green, .blue, .alpha:
            source = HistogramSource(texture: texture, resolvedChannel: channel)
        }

        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: clampedBins,
            histogramForAlpha: true,
            minPixelValue: vector_float4(0, 0, 0, 0),
            maxPixelValue: vector_float4(1, 1, 1, 1)
        )
        let histogram = MPSImageHistogram(device: source.texture.device, histogramInfo: &histogramInfo)
        histogram.zeroHistogram = true

        let bufferLength = histogram.histogramSize(forSourceFormat: source.texture.pixelFormat)
        guard bufferLength >= clampedBins * 4 * MemoryLayout<UInt32>.stride,
              let histogramBuffer = source.texture.device.makeBuffer(length: bufferLength, options: .storageModeShared),
              let commandQueue = source.texture.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return HistogramArtifacts(texture: source.texture, histogram: nil, buffer: nil, resolvedChannel: source.resolvedChannel)
        }

        histogram.encode(
            to: commandBuffer,
            sourceTexture: source.texture,
            histogram: histogramBuffer,
            histogramOffset: 0
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let channelIndex = source.resolvedChannel.channelIndex
        let stride = clampedBins
        let baseIndex = channelIndex * stride
        let pointer = histogramBuffer.contents().bindMemory(to: UInt32.self, capacity: bufferLength / MemoryLayout<UInt32>.stride)
        let counts = (0..<clampedBins).map { pointer[baseIndex + $0] }

        return HistogramArtifacts(
            texture: source.texture,
            histogram: TextureHistogram(
                channel: channel,
                bins: counts,
                totalSampleCount: source.texture.width * source.texture.height
            ),
            buffer: histogramBuffer,
            resolvedChannel: source.resolvedChannel
        )
    }

    private struct HistogramSource {
        let texture: MTLTexture
        let resolvedChannel: TextureHistogramChannel
    }

    private struct HistogramArtifacts {
        let texture: MTLTexture
        let histogram: TextureHistogram?
        let buffer: MTLBuffer?
        let resolvedChannel: TextureHistogramChannel
    }

    private static func makePreviewTexture(device: MTLDevice,
                                           histogram: TextureHistogram,
                                           histogramBuffer: MTLBuffer,
                                           resolvedChannel: TextureHistogramChannel,
                                           height: Int) -> MTLTexture? {
        let previewHeight = max(height, 1)
        guard let texture = try? TextureLoader.makeTexture(
            width: max(histogram.binCount, 1),
            height: previewHeight,
            options: [
                .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
            ],
            identifier: "GPUHistogram.preview"
        ),
        let commandQueue = device.makeCommandQueue(),
        let commandBuffer = commandQueue.makeCommandBuffer(),
        let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
        let pipeline = try? Compute.makeComputePipelineState(with: "histogramPreviewKernel") else {
            return nil
        }

        var params = HistogramPreviewParameters(
            histogramOffset: UInt32(resolvedChannel.channelIndex * histogram.binCount),
            histogramCount: UInt32(histogram.binCount),
            textureHeight: UInt32(previewHeight),
            peakCount: max(histogram.peakCount, 1)
        )
        var color = resolvedChannel.previewColor

        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(histogramBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&params, length: MemoryLayout<HistogramPreviewParameters>.stride, index: 1)
        computeEncoder.setBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
        computeEncoder.setTexture(texture, index: 0)

        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroupCount = MTLSize(
            width: max((texture.width + threadgroupSize.width - 1) / threadgroupSize.width, 1),
            height: max((texture.height + threadgroupSize.height - 1) / threadgroupSize.height, 1),
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }
}

private extension TextureHistogramChannel {
    var channelIndex: Int {
        switch self {
        case .red, .luminance:
            return 0
        case .green:
            return 1
        case .blue:
            return 2
        case .alpha:
            return 3
        }
    }

    var previewColor: SIMD4<Float> {
        switch self {
        case .red:
            return SIMD4<Float>(1.0, 0.25, 0.25, 1.0)
        case .green:
            return SIMD4<Float>(0.25, 1.0, 0.25, 1.0)
        case .blue:
            return SIMD4<Float>(0.25, 0.63, 1.0, 1.0)
        case .alpha:
            return SIMD4<Float>(0.86, 0.86, 0.86, 1.0)
        case .luminance:
            return SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        }
    }
}

private struct HistogramPreviewParameters {
    let histogramOffset: UInt32
    let histogramCount: UInt32
    let textureHeight: UInt32
    let peakCount: UInt32
}
#else
enum GPUHistogramSupport {
    static func makeHistogram(from texture: MTLTexture,
                              channel: TextureHistogramChannel,
                              bins: Int) -> TextureHistogram? {
        nil
    }

    static func makeRenderedHistogramAttachment(from texture: MTLTexture,
                                                channel: TextureHistogramChannel,
                                                bins: Int,
                                                height: Int) -> RenderedHistogramAttachment? {
        nil
    }
}
#endif
