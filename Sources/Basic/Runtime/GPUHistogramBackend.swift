//
//  GPUHistogramBackend.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal
#if canImport(MetalPerformanceShaders)
import MetalPerformanceShaders
import simd

/// Internal GPU backend for histogram computation and preview generation.
enum GPUHistogramBackend {

    static func makeHistogram(from texture: MTLTexture,
                              channel: TextureHistogramChannel,
                              bins: Int,
                              region: MTLRegion? = nil,
                              valueRange: TextureAnalysisValueRange = .normalized) -> TextureHistogram? {
        makeHistogramArtifacts(from: texture, channel: channel, bins: bins, region: region, valueRange: valueRange).histogram
    }

    static func makeRenderedHistogramAttachment(from texture: MTLTexture,
                                                channel: TextureHistogramChannel,
                                                bins: Int,
                                                height: Int,
                                                region: MTLRegion? = nil,
                                                valueRange: TextureAnalysisValueRange = .normalized) -> RenderedHistogramAttachment? {
        let artifacts = makeHistogramArtifacts(from: texture, channel: channel, bins: bins, region: region, valueRange: valueRange)
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
                                               bins: Int,
                                               region: MTLRegion?,
                                               valueRange: TextureAnalysisValueRange) -> HistogramArtifacts {
        let clampedBins = max(1, bins)
        guard let resolvedRegion = resolvedRegion(region, for: texture) else {
            return HistogramArtifacts(texture: texture, histogram: nil, buffer: nil, resolvedChannel: channel, sampleCount: 0)
        }
        let source: HistogramSource
        switch channel {
        case .luminance:
            guard let grayscale = try? HarbethIO(element: texture, filter: C7Grayed())
                .renderTexture(profile: .readbackQuality) else {
                return HistogramArtifacts(texture: texture, histogram: nil, buffer: nil, resolvedChannel: .red, sampleCount: 0)
            }
            source = HistogramSource(texture: grayscale, resolvedChannel: .red)
        case .red, .green, .blue, .alpha:
            source = HistogramSource(texture: texture, resolvedChannel: channel)
        }

        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: clampedBins,
            histogramForAlpha: true,
            minPixelValue: vector_float4(repeating: valueRange.minimum),
            maxPixelValue: vector_float4(repeating: valueRange.maximum)
        )
        let histogram = MPSImageHistogram(device: source.texture.device, histogramInfo: &histogramInfo)
        histogram.zeroHistogram = true
        histogram.clipRectSource = resolvedRegion

        let bufferLength = histogram.histogramSize(forSourceFormat: source.texture.pixelFormat)
        guard bufferLength >= clampedBins * 4 * MemoryLayout<UInt32>.stride,
              let histogramBuffer = source.texture.device.makeBuffer(length: bufferLength, options: .storageModeShared),
              let commandBuffer = makeCommandBuffer(device: source.texture.device) else {
            return HistogramArtifacts(texture: source.texture, histogram: nil, buffer: nil, resolvedChannel: source.resolvedChannel, sampleCount: 0)
        }

        histogram.encode(
            to: commandBuffer,
            sourceTexture: source.texture,
            histogram: histogramBuffer,
            histogramOffset: 0
        )
        do {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: "GPUHistogram")
        } catch {
            return HistogramArtifacts(texture: source.texture, histogram: nil, buffer: nil, resolvedChannel: source.resolvedChannel, sampleCount: 0)
        }

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
                totalSampleCount: resolvedRegion.size.width * resolvedRegion.size.height,
                valueRange: valueRange,
                pixelFormat: PixelFormatContract(pixelFormat: texture.pixelFormat, preservesInput: false)
            ),
            buffer: histogramBuffer,
            resolvedChannel: source.resolvedChannel,
            sampleCount: resolvedRegion.size.width * resolvedRegion.size.height
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
        let sampleCount: Int
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
        let commandBuffer = makeCommandBuffer(device: device),
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
        do {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: "GPUHistogram.preview")
        } catch {
            return nil
        }

        return texture
    }

    private static func resolvedRegion(_ requestedRegion: MTLRegion?, for texture: MTLTexture) -> MTLRegion? {
        let region = requestedRegion ?? MTLRegionMake2D(0, 0, texture.width, texture.height)
        let originX = min(max(region.origin.x, 0), texture.width)
        let originY = min(max(region.origin.y, 0), texture.height)
        let width = min(max(region.size.width, 0), max(texture.width - originX, 0))
        let height = min(max(region.size.height, 0), max(texture.height - originY, 0))
        guard width > 0, height > 0 else {
            return nil
        }
        return MTLRegionMake2D(originX, originY, width, height)
    }

    private static func makeCommandBuffer(device: MTLDevice) -> MTLCommandBuffer? {
        guard device === HarbethContext.shared.device else { return nil }
        return HarbethContext.shared.makeCommandBuffer()
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
enum GPUHistogramBackend {
    static func makeHistogram(from texture: MTLTexture,
                              channel: TextureHistogramChannel,
                              bins: Int,
                              region: MTLRegion? = nil,
                              valueRange: TextureAnalysisValueRange = .normalized) -> TextureHistogram? {
        nil
    }

    static func makeRenderedHistogramAttachment(from texture: MTLTexture,
                                                channel: TextureHistogramChannel,
                                                bins: Int,
                                                height: Int,
                                                region: MTLRegion? = nil,
                                                valueRange: TextureAnalysisValueRange = .normalized) -> RenderedHistogramAttachment? {
        nil
    }
}
#endif
