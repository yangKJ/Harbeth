//
//  TextureStructureStatistics.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import Foundation
import Metal

/// 渲染完成后的结构能量摘要；数值保持 Rec.709 storage 域，不隐式转换 ICC 或 transfer。
public struct TextureStructureStatistics: Sendable, Equatable {
    public let sampleCount: Int
    public let laplacianMeanSquare: Float
    public let gradientMeanSquare: Float

    init(sampleCount: Int, laplacianMeanSquare: Float, gradientMeanSquare: Float) {
        self.sampleCount = sampleCount
        self.laplacianMeanSquare = laplacianMeanSquare
        self.gradientMeanSquare = gradientMeanSquare
    }
}

private struct TextureStructurePartial {
    var laplacian: Float
    var gradient: Float
    var sampleCount: UInt32
    var invalid: UInt32
}

private enum TextureStructureStatisticsBackend {
    static let supportedFormats: Set<MTLPixelFormat> = [.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float]

    static func validate(_ texture: MTLTexture) throws {
        guard texture.device === HarbethContext.shared.device,
              supportedFormats.contains(texture.pixelFormat),
              texture.textureType == .type2D,
              texture.arrayLength == 1,
              texture.sampleCount == 1,
              texture.width >= 3,
              texture.height >= 3,
              texture.storageMode != .memoryless else {
            throw HarbethError.configurationInvalid("Structure statistics requires a readable RGBA texture.")
        }
    }

    static func make(_ texture: MTLTexture, alphaType: AlphaType, alphaThreshold: Float) throws -> TextureStructureStatistics {
        try validate(texture)
        guard alphaThreshold.isFinite, alphaThreshold >= 0, alphaThreshold <= 1 else {
            throw HarbethError.configurationInvalid("Invalid structure statistics alpha threshold.")
        }
        try Task.checkCancellation()
        guard let command = HarbethContext.shared.makeCommandBuffer() else { throw HarbethError.commandBuffer }
        defer { HarbethContext.shared.recycleCommandBuffer(command) }

        let pixelCount = texture.width.multipliedReportingOverflow(by: texture.height)
        guard !pixelCount.overflow, pixelCount.partialValue <= Int(UInt32.max) - 255 else {
            throw HarbethError.configurationInvalid("Structure statistics extent exceeds the counter domain.")
        }
        let firstCount = (pixelCount.partialValue + 255) / 256
        let bufferBytes = firstCount.multipliedReportingOverflow(by: MemoryLayout<TextureStructurePartial>.stride)
        guard !bufferBytes.overflow, bufferBytes.partialValue <= texture.device.maxBufferLength else {
            throw HarbethError.configurationInvalid("Structure statistics exceeds the buffer domain.")
        }
        guard var partials = texture.device.makeBuffer(
            length: bufferBytes.partialValue,
            options: firstCount == 1 ? .storageModeShared : .storageModePrivate
        ) else { throw HarbethError.commandBuffer }
        let pipeline = try Compute.makeComputePipelineState(with: "TextureStructureStatisticsBlocks")
        guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        let alphaMode: UInt32 = switch alphaType {
        case .premultiplied: 0
        case .nonPremultiplied: 1
        case .alphaIsOne: 2
        }
        var parameters = SIMD4<UInt32>(UInt32(texture.width), UInt32(texture.height), alphaMode, 0)
        var threshold = alphaThreshold
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(partials, offset: 0, index: 0)
        encoder.setBytes(&parameters, length: MemoryLayout<SIMD4<UInt32>>.stride, index: 1)
        encoder.setBytes(&threshold, length: MemoryLayout<Float>.stride, index: 2)
        encoder.dispatchThreadgroups(
            MTLSize(width: firstCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
        )
        encoder.endEncoding()

        let reducePipeline = try Compute.makeComputePipelineState(with: "TextureStructureStatisticsReduce")
        var count = firstCount
        while count > 1 {
            try Task.checkCancellation()
            let nextCount = (count + 255) / 256
            guard let next = texture.device.makeBuffer(
                length: nextCount * MemoryLayout<TextureStructurePartial>.stride,
                options: nextCount == 1 ? .storageModeShared : .storageModePrivate
            ), let reduce = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
            var inputCount = UInt32(count)
            reduce.setComputePipelineState(reducePipeline)
            reduce.setBuffer(partials, offset: 0, index: 0)
            reduce.setBuffer(next, offset: 0, index: 1)
            reduce.setBytes(&inputCount, length: MemoryLayout<UInt32>.stride, index: 2)
            reduce.dispatchThreadgroups(
                MTLSize(width: nextCount, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
            )
            reduce.endEncoding()
            partials = next
            count = nextCount
        }
        try Task.checkCancellation()
        try command.commitAndWaitUntilCompleted(identifier: "TextureStructureStatistics")
        try Task.checkCancellation()
        let result = partials.contents().bindMemory(to: TextureStructurePartial.self, capacity: 1).pointee
        guard result.invalid == 0,
              result.sampleCount == 0 || (result.laplacian.isFinite && result.gradient.isFinite
                  && result.laplacian >= 0 && result.gradient >= 0) else {
            throw HarbethError.configurationInvalid("Structure statistics contains non-finite values.")
        }
        let divisor = Float(max(result.sampleCount, 1))
        return TextureStructureStatistics(
            sampleCount: Int(result.sampleCount),
            laplacianMeanSquare: result.laplacian / divisor,
            gradientMeanSquare: result.gradient / divisor
        )
    }
}

public extension MTLTextureCompatible_ {
    func makeStructureStatistics(alphaType: AlphaType = .premultiplied, alphaThreshold: Float = 16 / 255) throws -> TextureStructureStatistics {
        try TextureStructureStatisticsBackend.make(target, alphaType: alphaType, alphaThreshold: alphaThreshold)
    }
}

public extension RenderedFrame {
    func makeStructureStatistics(alphaType: AlphaType? = nil, alphaThreshold: Float = 16 / 255) throws -> TextureStructureStatistics {
        try texture.c7.makeStructureStatistics(alphaType: alphaType ?? self.alphaType, alphaThreshold: alphaThreshold)
    }
}
