//
//  GPUTextureAnalysis.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import Foundation
import Metal

/// 保持纹理存储域语义；色域和 transfer function 不在分析时隐式转换。
enum GPUTextureAnalysis {
    private static func parameters(_ texture: MTLTexture, scope: TextureAnalysisScope) throws -> ([Float], MTLTexture?) {
        let formats: [MTLPixelFormat] = [.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float,
                                        .r8Unorm, .r16Float, .r32Float, .rg8Unorm, .rg16Float, .rg32Float, .a8Unorm]
        guard texture.device === HarbethContext.shared.device, formats.contains(texture.pixelFormat),
              texture.textureType == .type2D, texture.sampleCount == 1, texture.arrayLength == 1,
              texture.storageMode != .memoryless else { throw HarbethError.configurationInvalid("Unsupported analysis texture.") }
        guard let region = texture.c7.resolvedHistogramRegion(scope.region) else {
            throw HarbethError.configurationInvalid("Empty analysis region.")
        }
        let kind: Float = [.r8Unorm, .r16Float, .r32Float].contains(texture.pixelFormat) ? 1
            : ([.rg8Unorm, .rg16Float, .rg32Float].contains(texture.pixelFormat) ? 2 : (texture.pixelFormat == .a8Unorm ? 3 : 0))
        let mask = try scope.mask.map {
            try HarbethIO(element: $0.texture, filter: MaskCoverageExtract(mask: $0)).renderTexture(profile: .readbackQuality)
        }
        if let mask, mask.device !== texture.device { throw HarbethError.configurationInvalid("Analysis mask device mismatch.") }
        var p: [Float] = [Float(region.origin.x), Float(region.origin.y), Float(region.size.width), Float(region.size.height),
                          kind, mask == nil ? 0 : 1, scope.coverageThreshold,
                          scope.luminanceRange == nil ? 0 : 1, scope.luminanceRange?.minimum ?? 0, scope.luminanceRange?.maximum ?? 1]
        for range in [scope.colorRange?.hue, scope.colorRange?.saturation, scope.colorRange?.lightness] {
            p += [range == nil ? 0 : 1, range?.minimum ?? 0, range?.maximum ?? 1, range?.wrapsAroundUnit == true ? 1 : 0]
        }
        p += [scope.valueRange.minimum, scope.valueRange.maximum, 0, 256]
        return (p, mask)
    }

    private static func encode(_ name: String, command: MTLCommandBuffer, texture: MTLTexture,
                               mask: MTLTexture?, parameters: [Float], buffer: MTLBuffer, threads: Int) throws {
        let pipeline = try Compute.makeComputePipelineState(with: name)
        guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(mask ?? texture, index: 1)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        var p = parameters
        encoder.setBytes(&p, length: p.count * 4, index: 1)
        encoder.dispatchThreadgroups(MTLSize(width: (threads + 255) / 256, height: 1, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
        encoder.endEncoding()
    }

    static func statistics(_ texture: MTLTexture, scope: TextureAnalysisScope) -> TextureStatistics? {
        do {
            let (p, mask) = try parameters(texture, scope: scope)
            var count = (Int(p[2]) * Int(p[3]) + 255) / 256
            guard let command = HarbethContext.shared.makeCommandBuffer(),
                  var partials = texture.device.makeBuffer(length: count * 48, options: .storageModePrivate) else { return nil }
            defer { HarbethContext.shared.recycleCommandBuffer(command) }
            try encode("AnalysisStatisticsBlocks", command: command, texture: texture, mask: mask,
                       parameters: p, buffer: partials, threads: Int(p[2]) * Int(p[3]))
            let pipeline = try Compute.makeComputePipelineState(with: "AnalysisStatisticsReduce")
            // 归约树保留整数样本数，最后一级才建立 CPU 可见摘要。
            repeat {
                let nextCount = (count + 255) / 256
                guard let next = texture.device.makeBuffer(length: nextCount * 48,
                        options: nextCount == 1 ? .storageModeShared : .storageModePrivate),
                      let encoder = command.makeComputeCommandEncoder() else { return nil }
                var n = UInt32(count)
                encoder.setComputePipelineState(pipeline)
                encoder.setBuffer(partials, offset: 0, index: 0)
                encoder.setBuffer(next, offset: 0, index: 1)
                encoder.setBytes(&n, length: 4, index: 2)
                encoder.dispatchThreadgroups(MTLSize(width: nextCount, height: 1, depth: 1),
                                             threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
                encoder.endEncoding()
                partials = next
                count = nextCount
            } while count > 1
            try command.commitAndWaitUntilCompleted(identifier: "AnalysisStatistics")
            let values = partials.contents().bindMemory(to: Float.self, capacity: 12)
            let integers = partials.contents().bindMemory(to: UInt32.self, capacity: 12)
            guard integers[9] == 0 else { return nil }
            let samples = Int(integers[8]), divisor = Float(max(samples, 1))
            guard samples == 0 || (0...6).allSatisfy({ values[$0].isFinite }) else { return nil }
            return TextureStatistics(pixelFormat: PixelFormatContract(pixelFormat: texture.pixelFormat, preservesInput: false),
                sampleCount: samples, meanRed: values[0] / divisor, meanGreen: values[1] / divisor,
                meanBlue: values[2] / divisor, meanAlpha: values[3] / divisor, meanLuminance: values[4] / divisor,
                minimumLuminance: samples == 0 ? 0 : values[5], maximumLuminance: samples == 0 ? 0 : values[6])
        } catch { return nil }
    }

    static func histogram(_ texture: MTLTexture, channel: TextureHistogramChannel, bins: Int,
                          scope: TextureAnalysisScope) -> TextureHistogram? {
        guard bins > 0, bins <= 4096 else { return nil }
        do {
            var (p, mask) = try parameters(texture, scope: scope)
            switch channel {
            case .luminance: p[24] = 0
            case .red: p[24] = 1
            case .green: p[24] = 2
            case .blue: p[24] = 3
            case .alpha: p[24] = 4
            }
            p[25] = Float(bins)
            guard let command = HarbethContext.shared.makeCommandBuffer(),
                  let result = texture.device.makeBuffer(length: (bins + 2) * 4, options: .storageModeShared) else { return nil }
            defer { HarbethContext.shared.recycleCommandBuffer(command) }
            memset(result.contents(), 0, result.length)
            try encode("AnalysisScopedHistogram", command: command, texture: texture, mask: mask,
                       parameters: p, buffer: result, threads: Int(p[2]) * Int(p[3]))
            try command.commitAndWaitUntilCompleted(identifier: "AnalysisScopedHistogram")
            let values = result.contents().bindMemory(to: UInt32.self, capacity: bins + 2)
            guard values[bins + 1] == 0 else { return nil }
            return TextureHistogram(channel: channel, bins: Array(UnsafeBufferPointer(start: values, count: bins)),
                totalSampleCount: Int(values[bins]), valueRange: scope.valueRange,
                pixelFormat: PixelFormatContract(pixelFormat: texture.pixelFormat, preservesInput: false))
        } catch { return nil }
    }

    static func mask(_ texture: MTLTexture, scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat) throws -> MTLTexture? {
        let (p, mask) = try parameters(texture, scope: scope)
        let output = try TextureLoader.makeTexture(width: texture.width, height: texture.height,
            options: [.texturePixelFormat: pixelFormat, .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])], identifier: "AnalysisMask")
        guard let command = HarbethContext.shared.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        defer { HarbethContext.shared.recycleCommandBuffer(command) }
        let pipeline = try Compute.makeComputePipelineState(with: "AnalysisScopeMask")
        var parameters = p
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(mask ?? texture, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&parameters, length: parameters.count * 4, index: 1)
        encoder.dispatchThreads(MTLSize(width: texture.width, height: texture.height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding()
        try command.commitAndWaitUntilCompleted(identifier: "AnalysisScopeMask")
        return output
    }
}
