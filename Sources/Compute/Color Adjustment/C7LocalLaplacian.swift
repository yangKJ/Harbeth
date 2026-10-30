//
//  C7LocalLaplacian.swift
//  Harbeth
//
//  Created by Condy on 2026/10/30.
//

import Foundation
import Metal

/// 亮度域的采样局部拉普拉斯。以源 Gaussian 层选择重映射残差，保留粗尺度与输入 alpha。
public struct C7LocalLaplacian: C7MetalCommandEncodingProtocol {
    public var detail: Float
    public var rangeSigma: Float
    public var intensity: Float
    public let sampleCount: Int
    public let maximumLevels: Int

    public init(
        detail: Float = 1,
        rangeSigma: Float = 0.15,
        intensity: Float = 1,
        sampleCount: Int = 8,
        maximumLevels: Int = 6
    ) {
        self.detail = detail
        self.rangeSigma = rangeSigma
        self.intensity = intensity
        self.sampleCount = min(16, max(2, sampleCount))
        self.maximumLevels = min(8, max(2, maximumLevels))
    }

    public var modifier: ModifierEnum { .metalCommand(label: "C7LocalLaplacian") }
    public var factors: [Float] { [detail, rangeSigma, intensity, Float(sampleCount), Float(maximumLevels)] }
    public var memoryAccessPattern: MemoryAccessPattern { .multiTexture }
    public var destinationTextureContract: FilterDestinationTextureContract {
        .init(aliasingPolicy: .requiredDistinct)
    }
    public var kernelOutputContract: RenderOutputContract { .init(alpha: .premultiplied) }
    public var kernelPixelContract: KernelPixelContract {
        .init(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float32,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .global,
            coordinateDependency: .fullImage,
            fusionPolicy: .disabled
        )
    }

    public func validate() throws {
        guard detail.isFinite, (-1...2).contains(detail), rangeSigma.isFinite, (0.01...1).contains(rangeSigma),
              intensity.isFinite, (0...1).contains(intensity) else {
            throw HarbethError.filterParameterInvalid("局部拉普拉斯参数越界或非有限")
        }
    }

    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }

    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        try validate()
        guard route == .preferred else { throw HarbethError.filterParameterInvalid("局部拉普拉斯不支持替代路线") }
        let source = context.sourceTexture
        let output = context.destinationTexture
        guard source.width == output.width, source.height == output.height else { throw HarbethError.textureSizeMismatch }
        if intensity == 0 || detail == 0 {
            guard let blit = context.commandBuffer.makeBlitCommandEncoder() else { throw HarbethError.makeBlitCommandEncoder }
            blit.copy(from: source, to: output)
            blit.endEncoding()
            return output
        }
        let sizes = LocalLaplacianEncoding.pyramidSizes(width: source.width, height: source.height, maximumLevels: maximumLevels)
        // 四组 RG32 层复用全部亮度采样，禁止每个采样长期保留一整组金字塔。
        let required = sizes.reduce(Int64(0)) { $0 + Int64($1.x) * Int64($1.y) * 32 }
        guard required <= 512 * 1_024 * 1_024 else {
            throw HarbethError.configurationInvalid("局部拉普拉斯整图工作集超限，请使用区域执行器")
        }
        func pyramid() throws -> [MTLTexture] {
            try sizes.map { size in
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rg32Float,
                    width: Int(size.x),
                    height: Int(size.y),
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .private
                guard let texture = context.device.makeTexture(descriptor: descriptor) else { throw HarbethError.makeTexture }
                return texture
            }
        }
        let guide = try pyramid()
        let remapped = try pyramid()
        var sums = try pyramid()
        var scratch = try pyramid()
        let command = context.commandBuffer
        func encode(_ operation: LocalLaplacianOperation, _ inputs: [MTLTexture], _ destination: MTLTexture, _ level: Int, reference: Float = 0) throws {
            let coarse = operation == .apply ? sizes[level] : sizes[min(level + 1, sizes.count - 1)]
            try LocalLaplacianEncoding.encode(
                operation: operation,
                inputs: inputs,
                destination: destination,
                region: .init(inputExtent: sizes[level], coarseExtent: coarse),
                detail: detail,
                rangeSigma: rangeSigma,
                reference: reference,
                step: 1 / Float(sampleCount - 1),
                intensity: intensity,
                commandBuffer: command
            )
        }
        try encode(.luminance, [source], guide[0], 0)
        for level in 1..<sizes.count {
            try LocalLaplacianEncoding.encode(
                operation: .reduce,
                inputs: [guide[level - 1]],
                destination: guide[level],
                region: .init(inputExtent: sizes[level - 1]),
                commandBuffer: command
            )
        }
        for level in 0..<(sizes.count - 1) { try encode(.clear, [guide[level]], sums[level], level) }
        for sample in 0..<sampleCount {
            let reference = Float(sample) / Float(sampleCount - 1)
            try encode(.remap, [guide[0]], remapped[0], 0, reference: reference)
            for level in 1..<sizes.count {
                try LocalLaplacianEncoding.encode(
                    operation: .reduce,
                    inputs: [remapped[level - 1]],
                    destination: remapped[level],
                    region: .init(inputExtent: sizes[level - 1]),
                    commandBuffer: command
                )
            }
            for level in 0..<(sizes.count - 1) {
                try encode(
                    .accumulate,
                    [remapped[level], remapped[level + 1], guide[level], sums[level]],
                    scratch[level],
                    level,
                    reference: reference
                )
            }
            swap(&sums, &scratch)
        }
        var reconstructed = guide[sizes.count - 1]
        for level in (0..<(sizes.count - 1)).reversed() {
            try encode(.reconstruct, [sums[level], reconstructed], remapped[level], level)
            reconstructed = remapped[level]
        }
        try encode(.apply, [source, reconstructed], output, 0)
        return output
    }
}

/// 各阶段共用一个坐标合同；上层区域执行器只提供有界 ROI，不拥有图像算法。
public struct LocalLaplacianRegion: Sendable {
    public let inputOrigin: SIMD2<UInt32>
    public let outputOrigin: SIMD2<UInt32>
    public let inputExtent: SIMD2<UInt32>
    public let coarseOrigin: SIMD2<UInt32>
    public let coarseExtent: SIMD2<UInt32>
    public let guideOrigin: SIMD2<UInt32>
    public let sumOrigin: SIMD2<UInt32>

    public init(
        inputOrigin: SIMD2<UInt32> = .zero,
        outputOrigin: SIMD2<UInt32> = .zero,
        inputExtent: SIMD2<UInt32>,
        coarseOrigin: SIMD2<UInt32> = .zero,
        coarseExtent: SIMD2<UInt32>? = nil,
        guideOrigin: SIMD2<UInt32> = .zero,
        sumOrigin: SIMD2<UInt32> = .zero
    ) {
        self.inputOrigin = inputOrigin
        self.outputOrigin = outputOrigin
        self.inputExtent = inputExtent
        self.coarseOrigin = coarseOrigin
        self.coarseExtent = coarseExtent ?? inputExtent
        self.guideOrigin = guideOrigin
        self.sumOrigin = sumOrigin
    }
}

public enum LocalLaplacianOperation: UInt32, Sendable {
    case luminance, remap, reduce, clear, accumulate, reconstruct, apply
}

/// 滤镜开发合同：整图与分块共享同一套 GPU 步骤和精度，不另建图像处理入口。
public enum LocalLaplacianEncoding {
    public static func pyramidSizes(width: Int, height: Int, maximumLevels: Int) -> [SIMD2<UInt32>] {
        guard width > 0, height > 0, width <= Int(Int32.max), height <= Int(Int32.max) else { return [] }
        var sizes = [SIMD2<UInt32>(UInt32(width), UInt32(height))]
        while sizes.count < min(8, max(2, maximumLevels)), let last = sizes.last, last.x > 1 || last.y > 1 {
            sizes.append(SIMD2((last.x + 1) / 2, (last.y + 1) / 2))
        }
        return sizes
    }

    public static func encode(
        operation: LocalLaplacianOperation,
        inputs: [MTLTexture],
        destination: MTLTexture,
        region: LocalLaplacianRegion,
        detail: Float = 1,
        rangeSigma: Float = 0.15,
        reference: Float = 0,
        step: Float = 1 / 7,
        intensity: Float = 1,
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let first = inputs.first, !inputs.contains(where: { $0 === destination }),
              inputs.allSatisfy({ $0.device === commandBuffer.device }), destination.device === commandBuffer.device,
              region.inputExtent.x > 0, region.inputExtent.y > 0,
              region.inputExtent.x <= UInt32(Int32.max),
              region.inputExtent.y <= UInt32(Int32.max) else {
            throw HarbethError.filterParameterInvalid("局部拉普拉斯阶段输入或目标无效")
        }
        let requiredInputCount: Int
        switch operation {
        case .accumulate: requiredInputCount = 4
        case .reconstruct, .apply: requiredInputCount = 2
        default: requiredInputCount = 1
        }
        let outputExtent = operation == .reduce
            ? SIMD2<UInt32>((region.inputExtent.x + 1) / 2, (region.inputExtent.y + 1) / 2) : region.inputExtent
        guard inputs.count == requiredInputCount, [detail, rangeSigma, reference, step, intensity].allSatisfy(\.isFinite),
              rangeSigma > 0, step > 0, (0...1).contains(intensity),
              Int(region.inputOrigin.x) + first.width <= Int(region.inputExtent.x),
              Int(region.inputOrigin.y) + first.height <= Int(region.inputExtent.y),
              Int(region.outputOrigin.x) + destination.width <= Int(outputExtent.x),
              Int(region.outputOrigin.y) + destination.height <= Int(outputExtent.y) else {
            throw HarbethError.filterParameterInvalid("局部拉普拉斯阶段参数或ROI越界")
        }
        if inputs.count > 1 {
            guard region.coarseExtent.x > 0, region.coarseExtent.y > 0,
                  Int(region.coarseOrigin.x) + inputs[1].width <= Int(region.coarseExtent.x),
                  Int(region.coarseOrigin.y) + inputs[1].height <= Int(region.coarseExtent.y) else {
                throw HarbethError.filterParameterInvalid("局部拉普拉斯相邻层ROI越界")
            }
        }
        let pipeline = try MetalCommandEnvironment(device: commandBuffer.device).makeComputePipelineState(
            .init(kind: .compute, primaryName: "localLaplacianStage")
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
        encoder.label = "LocalLaplacian.\(operation)"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(destination, index: 0)
        for index in 0..<4 { encoder.setTexture(index < inputs.count ? inputs[index] : first, index: index + 1) }
        let coordinates = [
            SIMD4(operation.rawValue, region.outputOrigin.x, region.outputOrigin.y, 0),
            SIMD4(region.inputOrigin.x, region.inputOrigin.y, region.inputExtent.x, region.inputExtent.y),
            SIMD4(region.coarseOrigin.x, region.coarseOrigin.y, region.coarseExtent.x, region.coarseExtent.y),
            SIMD4(region.guideOrigin.x, region.guideOrigin.y, region.sumOrigin.x, region.sumOrigin.y)
        ]
        coordinates.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 0) }
        var values = SIMD4(detail, rangeSigma, reference, step)
        var amount = intensity
        encoder.setBytes(&values, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
        encoder.setBytes(&amount, length: MemoryLayout<Float>.stride, index: 2)
        let threads = MTLSize(width: 16, height: 16, depth: 1)
        encoder.dispatchThreadgroups(
            MTLSize(width: (destination.width + 15) / 16, height: (destination.height + 15) / 16, depth: 1),
            threadsPerThreadgroup: threads
        )
        encoder.endEncoding()
    }
}
