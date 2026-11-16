//
//  C7Clarity.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation
import Metal

/// 清晰度滤镜
/// Clarity filter
public struct C7Clarity: C7MetalCommandEncodingProtocol, TemporaryTextureRequirementProviding {
    
    /// 清晰度强度，0.0 到 1.0，默认 1.0
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// 半径，0.0 到 1.0，默认 0.12
    @ZeroOneRange public var radius: Float = 0.12
    
    public var modifier: ModifierEnum {
        safeRadius > 0 && safeIntensity > 0 ? .metalCommand(label: "C7Clarity") : .compute(kernel: "C7Clarity")
    }
    
    public var computeKernelLibrarySource: KernelLibrarySource { .harbethFramework }

    public var factors: [Float] {
        return [safeIntensity, safeRadius]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(radius: safeIntensity == 0 ? 0 : Int(ceil(safeRadius * 100)))
        )
    }

    public init(intensity: Float = 1.0, radius: Float = 0.12) {
        self.intensity = intensity
        self.radius = radius
    }

    private var safeRadius: Float { radius.isFinite ? min(max(radius, 0), 1) : 0 }
    private var safeIntensity: Float { intensity.isFinite ? min(max(intensity, 0), 1) : 0 }

    public var destinationTextureContract: FilterDestinationTextureContract { .init(aliasingPolicy: .requiredDistinct) }

    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }

    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        let limit = min(128 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 3)
        return try encode(context: context, maximumTemporaryBytes: limit)
    }

    // 内部预算参数供离线验收强制回退，不增加普通使用入口。
    func encode(context: MetalCommandEncodingContext, maximumTemporaryBytes: Int) throws -> MTLTexture {
        let source = context.sourceTexture
        guard Self.usesSeparable(width: source.width, height: source.height, radius: safeRadius,
                                 maximumTemporaryBytes: maximumTemporaryBytes), safeIntensity > 0,
              source.width == context.destinationTexture.width, source.height == context.destinationTexture.height else {
            return try encodeDirect(context)
        }
        let bytes = source.width * source.height * 16
        let budget = ClarityScratchBudget.shared
        guard budget.reserve(bytes, limit: maximumTemporaryBytes) else { return try encodeDirect(context) }
        let temporary: TextureLease
        do {
            temporary = try TextureLoader.makeTextureLease(width: source.width, height: source.height,
                options: [.texturePixelFormat: MTLPixelFormat.rgba32Float, .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite]),
                          .textureStorageMode: MTLStorageMode.private], identifier: "ClarityTemporary")
        } catch {
            budget.release(bytes)
            return try encodeDirect(context)
        }
        // 组合租约在 GPU 完成或未提交的命令缓冲区销毁后，同时归还表面和预算。
        let owned = TextureLease(texture: temporary.texture) {
            temporary.release()
            budget.release(bytes)
        }
        context.commandBuffer.addCompletedHandler { _ in owned.release() }
        let sigma = safeRadius * 10
        var radius = Int32(ceil(sigma * 10)), intensity = safeIntensity
        let weights = (-Int(radius)...Int(radius)).map { offset in
            offset == 0 ? Float(1) : exp(-Float(offset * offset) / (2 * sigma * sigma))
        }
        for (name, vertical) in [("ClarityHorizontal", false), ("ClarityVertical", true)] {
            let identity = KernelFunctionIdentity(kind: .compute, primaryName: name, librarySource: .harbethFramework)
            let pipeline = try context.environment.makeComputePipelineState(identity)
            guard let encoder = context.commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(source, index: 0)
            encoder.setTexture(temporary.texture, index: 1)
            if vertical { encoder.setTexture(context.destinationTexture, index: 2) }
            encoder.setBytes(&radius, length: 4, index: 0)
            weights.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 1) }
            if vertical { encoder.setBytes(&intensity, length: 4, index: 2) }
            let groups = MTLSize(width: (source.width + 15) / 16, height: (source.height + 15) / 16, depth: 1)
            encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
            encoder.endEncoding()
        }
        return context.destinationTexture
    }

    static func usesSeparable(width: Int, height: Int, radius: Float, maximumTemporaryBytes: Int) -> Bool {
        guard width > 0, height > 0, radius.isFinite, radius >= 0.04,
              maximumTemporaryBytes > 0, width <= maximumTemporaryBytes / 16 / height else { return false }
        return width * height >= 4096
    }

    func temporaryTextureRequirement(inputSize: C7Size) -> (bytes: Int, count: Int) {
        let width = Int(inputSize.width), height = Int(inputSize.height)
        let limit = min(128 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 3)
        guard safeIntensity > 0, Self.usesSeparable(width: width, height: height, radius: safeRadius,
                                                   maximumTemporaryBytes: limit) else { return (0, 0) }
        return (width * height * 16, 1)
    }

    private func encodeDirect(_ context: MetalCommandEncodingContext) throws -> MTLTexture {
        let filter = ClarityDirectFilter(factors: factors)
        return try filter.applyAtTexture(form: context.sourceTexture, to: context.destinationTexture, for: context.commandBuffer)
    }
}

private struct ClarityDirectFilter: C7FilterProtocol {
    let factors: [Float]
    var modifier: ModifierEnum { .compute(kernel: "C7Clarity") }
    var computeKernelLibrarySource: KernelLibrarySource { .harbethFramework }
}

/// 并发请求共享有界的在途表面额度；缓存重置不能释放仍被 GPU 使用的额度。
final class ClarityScratchBudget: @unchecked Sendable {
    static let shared = ClarityScratchBudget()
    private let lock = NSLock()
    private var usedBytes = 0

    func reserve(_ bytes: Int, limit: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard bytes > 0, bytes <= limit, usedBytes <= limit - bytes else { return false }
        usedBytes += bytes
        return true
    }

    func release(_ bytes: Int) {
        lock.lock()
        usedBytes -= bytes
        lock.unlock()
    }
}
