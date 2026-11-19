//
//  GPUTextureAnalysis.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import Foundation
import Metal

/// 单次请求的分析结果；不缓存可变来源或 mask，也不形成新的普通使用入口。
struct TextureAnalysisArtifacts {
    let statistics: TextureStatistics?
    let histogram: TextureHistogram?
    let histogramAttachment: RenderedHistogramAttachment?
}

/// 数值保持纹理存储域，不隐式转换色域或 transfer function。
enum GPUTextureAnalysis {
    private struct PreparedScope {
        let parameters: [Float]
        let mask: MTLTexture?
        let lease: TextureLease?
    }

    private static func prepare(_ texture: MTLTexture, scope: TextureAnalysisScope, command: MTLCommandBuffer) throws -> PreparedScope {
        let formats: [MTLPixelFormat] = [
            .rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float,
            .r8Unorm, .r16Float, .r32Float, .rg8Unorm,
            .rg16Float, .rg32Float, .a8Unorm
        ]
        guard texture.device === HarbethContext.shared.device, formats.contains(texture.pixelFormat),
              texture.textureType == .type2D, texture.sampleCount == 1, texture.arrayLength == 1,
              texture.storageMode != .memoryless else {
            throw HarbethError.configurationInvalid("Unsupported analysis texture.")
        }
        guard let region = texture.c7.resolvedHistogramRegion(scope.region) else {
            throw HarbethError.configurationInvalid("Empty analysis region.")
        }
        let kind: Float = [.r8Unorm, .r16Float, .r32Float].contains(texture.pixelFormat) ? 1
            : ([.rg8Unorm, .rg16Float, .rg32Float].contains(texture.pixelFormat) ? 2 : (texture.pixelFormat == .a8Unorm ? 3 : 0))
        var lease: TextureLease?
        if let mask = scope.mask {
            guard mask.texture.device === texture.device else {
                throw HarbethError.configurationInvalid("Analysis mask device mismatch.")
            }
            let normalized = try TextureLoader.makeTextureLease(
                width: mask.texture.width, height: mask.texture.height,
                options: [
                    .texturePixelFormat: mask.texture.pixelFormat,
                    .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
                ],
                identifier: "AnalysisMask"
            )
            do {
                _ = try MaskCoverageExtract(mask: mask)
                    .applyAtTexture(form: mask.texture, to: normalized.texture, for: command)
            } catch {
                normalized.release()
                throw error
            }
            lease = normalized
        }
        var p: [Float] = [
            Float(region.origin.x), Float(region.origin.y),
            Float(region.size.width), Float(region.size.height),
            kind, lease == nil ? 0 : 1,
            scope.coverageThreshold,
            scope.luminanceRange == nil ? 0 : 1,
            scope.luminanceRange?.minimum ?? 0,
            scope.luminanceRange?.maximum ?? 1
        ]
        for range in [scope.colorRange?.hue, scope.colorRange?.saturation, scope.colorRange?.lightness] {
            p += [range == nil ? 0 : 1, range?.minimum ?? 0, range?.maximum ?? 1, range?.wrapsAroundUnit == true ? 1 : 0]
        }
        p += [scope.valueRange.minimum, scope.valueRange.maximum, 0, 256]
        return PreparedScope(parameters: p, mask: lease?.texture, lease: lease)
    }

    private static func encode(_ name: String, command: MTLCommandBuffer, texture: MTLTexture,
                               scope: PreparedScope, parameters: [Float], buffer: MTLBuffer, threads: Int,
                               histogram: Bool = false) throws {
        let pipeline = try Compute.makeComputePipelineState(with: name)
        guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(scope.mask ?? texture, index: 1)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        var p = parameters
        if histogram {
            p.append(Float(pipeline.threadExecutionWidth))
            let bytes = (Int(p[25]) * 4 + 15) & ~15
            encoder.setThreadgroupMemoryLength(bytes, index: 0)
        }
        encoder.setBytes(&p, length: p.count * 4, index: 1)
        encoder.dispatchThreadgroups(
            MTLSize(width: (threads + 255) / 256, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
        )
        encoder.endEncoding()
    }

    private static func encodeStatistics(_ texture: MTLTexture, scope: PreparedScope, command: MTLCommandBuffer) throws -> MTLBuffer {
        let p = scope.parameters
        var count = (Int(p[2]) * Int(p[3]) + 255) / 256
        guard var partials = texture.device.makeBuffer(length: count * 48, options: .storageModePrivate) else {
            throw HarbethError.commandBuffer
        }
        try encode(
            "AnalysisStatisticsBlocks",
            command: command, texture: texture, scope: scope,
            parameters: p, buffer: partials,
            threads: Int(p[2]) * Int(p[3])
        )
        let pipeline = try Compute.makeComputePipelineState(with: "AnalysisStatisticsReduce")
        repeat {
            let nextCount = (count + 255) / 256
            guard let next = texture.device.makeBuffer(
                length: nextCount * 48,
                options: nextCount == 1 ? .storageModeShared : .storageModePrivate
            ), let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
            var n = UInt32(count)
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(partials, offset: 0, index: 0)
            encoder.setBuffer(next, offset: 0, index: 1)
            encoder.setBytes(&n, length: 4, index: 2)
            encoder.dispatchThreadgroups(
                MTLSize(width: nextCount, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
            )
            encoder.endEncoding()
            partials = next
            count = nextCount
        } while count > 1
        return partials
    }

    private static func decodeStatistics(_ texture: MTLTexture, buffer: MTLBuffer) -> TextureStatistics? {
        let values = buffer.contents().bindMemory(to: Float.self, capacity: 12)
        let integers = buffer.contents().bindMemory(to: UInt32.self, capacity: 12)
        guard integers[9] == 0 else { return nil }
        let samples = Int(integers[8]), divisor = Float(max(samples, 1))
        guard samples == 0 || (0...6).allSatisfy({ values[$0].isFinite }) else { return nil }
        return TextureStatistics(
            pixelFormat: PixelFormatContract(pixelFormat: texture.pixelFormat, preservesInput: false),
            sampleCount: samples,
            meanRed: values[0] / divisor,
            meanGreen: values[1] / divisor,
            meanBlue: values[2] / divisor,
            meanAlpha: values[3] / divisor,
            meanLuminance: values[4] / divisor,
            minimumLuminance: samples == 0 ? 0 : values[5],
            maximumLuminance: samples == 0 ? 0 : values[6]
        )
    }

    private static func encodeHistogram(_ texture: MTLTexture, scope: PreparedScope, channel: TextureHistogramChannel,
                                        bins: Int, command: MTLCommandBuffer) throws -> MTLBuffer {
        var p = scope.parameters
        switch channel {
        case .luminance: p[24] = 0
        case .red: p[24] = 1
        case .green: p[24] = 2
        case .blue: p[24] = 3
        case .alpha: p[24] = 4
        }
        p[25] = Float(bins)
        guard let result = texture.device.makeBuffer(length: (bins + 2) * 4, options: .storageModeShared) else { throw HarbethError.commandBuffer }
        memset(result.contents(), 0, result.length)
        #if targetEnvironment(simulator)
        let simd = false
        #else
        let simd = bins >= 32 && (texture.device.supportsFamily(.apple7) || texture.device.supportsFamily(.mac2))
        #endif
        let kernel = simd ? "AnalysisScopedHistogramSIMD" : "AnalysisScopedHistogram"
        try encode(
            kernel, command: command, texture: texture,
            scope: scope, parameters: p, buffer: result,
            threads: Int(p[2]) * Int(p[3]), histogram: true
        )
        return result
    }

    private static func decodeHistogram(_ texture: MTLTexture, buffer: MTLBuffer, channel: TextureHistogramChannel,
                                        bins: Int, valueRange: TextureAnalysisValueRange) -> TextureHistogram? {
        let values = buffer.contents().bindMemory(to: UInt32.self, capacity: bins + 2)
        guard values[bins + 1] == 0 else { return nil }
        return TextureHistogram(
            channel: channel,
            bins: Array(UnsafeBufferPointer(start: values, count: bins)),
            totalSampleCount: Int(values[bins]),
            valueRange: valueRange,
            pixelFormat: PixelFormatContract(pixelFormat: texture.pixelFormat, preservesInput: false)
        )
    }

    /// 参数准备、mask、统计、直方图和预览都属于本次请求，完成后再读取摘要。
    static func bundle(_ texture: MTLTexture, channel: TextureHistogramChannel, bins: Int, height: Int,
                       scope: TextureAnalysisScope) -> TextureAnalysisArtifacts? {
        guard bins > 0, bins <= 4096 else { return nil }
        do {
            guard let command = HarbethContext.shared.makeCommandBuffer() else { return nil }
            defer { HarbethContext.shared.recycleCommandBuffer(command) }
            let prepared = try prepare(texture, scope: scope, command: command)
            defer { prepared.lease?.release() }
            let statistics = try encodeStatistics(texture, scope: prepared, command: command)
            let histogram = try encodeHistogram(texture, scope: prepared, channel: channel, bins: bins, command: command)
            let preview = try encodePreview(
                texture.device, histogram: histogram, channel: channel,
                bins: bins, height: max(1, height),
                command: command
            )
            try command.commitAndWaitUntilCompleted(identifier: "AnalysisBundle")
            let decoded = decodeHistogram(texture, buffer: histogram, channel: channel, bins: bins, valueRange: scope.valueRange)
            let attachment = decoded.map {
                RenderedHistogramAttachment(histogram: $0, attachment: RenderedAttachment(
                    index: 1, semantic: .histogram,
                    texture: preview,
                    debugPolicy: RenderOutputAttachmentContract.histogram(index: 1, pixelFormat: .rgba8Unorm).debugPolicy
                ))
            }
            return TextureAnalysisArtifacts(
                statistics: decodeStatistics(texture, buffer: statistics),
                histogram: decoded,
                histogramAttachment: attachment
            )
        } catch { return nil }
    }

    static func histogramAttachment(_ texture: MTLTexture, channel: TextureHistogramChannel, bins: Int,
                                    height: Int, scope: TextureAnalysisScope) -> RenderedHistogramAttachment? {
        guard bins > 0, bins <= 4096 else { return nil }
        do {
            guard let command = HarbethContext.shared.makeCommandBuffer() else { return nil }
            defer { HarbethContext.shared.recycleCommandBuffer(command) }
            let prepared = try prepare(texture, scope: scope, command: command)
            defer { prepared.lease?.release() }
            let result = try encodeHistogram(texture, scope: prepared, channel: channel, bins: bins, command: command)
            let preview = try encodePreview(texture.device, histogram: result, channel: channel, bins: bins, height: max(1, height), command: command)
            try command.commitAndWaitUntilCompleted(identifier: "AnalysisHistogramAttachment")
            guard let histogram = decodeHistogram(texture, buffer: result, channel: channel, bins: bins, valueRange: scope.valueRange) else { return nil }
            return RenderedHistogramAttachment(histogram: histogram, attachment: RenderedAttachment(
                index: 1,
                semantic: .histogram, texture: preview,
                debugPolicy: RenderOutputAttachmentContract.histogram(index: 1, pixelFormat: .rgba8Unorm).debugPolicy
            ))
        } catch { return nil }
    }

    private static func encodePreview(_ device: MTLDevice, histogram: MTLBuffer, channel: TextureHistogramChannel, bins: Int, height: Int, command: MTLCommandBuffer) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: bins, height: height, mipmapped: false)
        descriptor.storageMode = .private; descriptor.usage = [.shaderRead, .shaderWrite]
        guard let output = device.makeTexture(descriptor: descriptor),
              let params = device.makeBuffer(length: 16, options: .storageModeShared) else { throw HarbethError.makeTexture }
        let values: [UInt32] = [0, UInt32(bins), UInt32(height), 0]
        values.withUnsafeBytes { params.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        let peakPipeline = try Compute.makeComputePipelineState(with: "AnalysisHistogramPeak")
        guard let peak = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        peak.setComputePipelineState(peakPipeline)
        peak.setBuffer(histogram, offset: 0, index: 0); peak.setBuffer(params, offset: 0, index: 1)
        peak.dispatchThreadgroups(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
        )
        peak.endEncoding()
        let pipeline = try Compute.makeComputePipelineState(with: "histogramPreviewKernel")
        guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        var color: SIMD4<Float>
        switch channel {
        case .red: color = SIMD4(1, 64.0 / 255, 64.0 / 255, 1)
        case .green: color = SIMD4(64.0 / 255, 1, 64.0 / 255, 1)
        case .blue: color = SIMD4(64.0 / 255, 160.0 / 255, 1, 1)
        case .alpha: color = SIMD4(220.0 / 255, 220.0 / 255, 220.0 / 255, 1)
        case .luminance: color = SIMD4(repeating: 1)
        }
        encoder.setComputePipelineState(pipeline); encoder.setTexture(output, index: 0)
        encoder.setBuffer(histogram, offset: 0, index: 0); encoder.setBuffer(params, offset: 0, index: 1)
        encoder.setBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
        encoder.dispatchThreads(
            MTLSize(width: bins, height: height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
        )
        encoder.endEncoding()
        return output
    }

    static func statistics(_ texture: MTLTexture, scope: TextureAnalysisScope) -> TextureStatistics? {
        do {
            guard let command = HarbethContext.shared.makeCommandBuffer() else { return nil }
            defer { HarbethContext.shared.recycleCommandBuffer(command) }
            let prepared = try prepare(texture, scope: scope, command: command)
            defer { prepared.lease?.release() }
            let result = try encodeStatistics(texture, scope: prepared, command: command)
            try command.commitAndWaitUntilCompleted(identifier: "AnalysisStatistics")
            return decodeStatistics(texture, buffer: result)
        } catch { return nil }
    }

    static func histogram(_ texture: MTLTexture, channel: TextureHistogramChannel, bins: Int, scope: TextureAnalysisScope) -> TextureHistogram? {
        guard bins > 0, bins <= 4096 else { return nil }
        do {
            guard let command = HarbethContext.shared.makeCommandBuffer() else { return nil }
            defer { HarbethContext.shared.recycleCommandBuffer(command) }
            let prepared = try prepare(texture, scope: scope, command: command)
            defer { prepared.lease?.release() }
            let result = try encodeHistogram(texture, scope: prepared, channel: channel, bins: bins, command: command)
            try command.commitAndWaitUntilCompleted(identifier: "AnalysisScopedHistogram")
            return decodeHistogram(texture, buffer: result, channel: channel, bins: bins, valueRange: scope.valueRange)
        } catch { return nil }
    }

    static func mask(_ texture: MTLTexture, scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat) throws -> MTLTexture? {
        guard let command = HarbethContext.shared.makeCommandBuffer() else { throw HarbethError.commandBuffer }
        defer { HarbethContext.shared.recycleCommandBuffer(command) }
        let prepared = try prepare(texture, scope: scope, command: command)
        defer { prepared.lease?.release() }
        let output = try TextureLoader.makeTexture(
            width: texture.width, height: texture.height,
            options: [
                .texturePixelFormat: pixelFormat,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
            ],
            identifier: "AnalysisMask"
        )
        guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        let pipeline = try Compute.makeComputePipelineState(with: "AnalysisScopeMask")
        var p = prepared.parameters
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(prepared.mask ?? texture, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&p, length: p.count * 4, index: 1)
        encoder.dispatchThreads(
            MTLSize(width: texture.width, height: texture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
        )
        encoder.endEncoding()
        try command.commitAndWaitUntilCompleted(identifier: "AnalysisScopeMask")
        return output
    }
}
