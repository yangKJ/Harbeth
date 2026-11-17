//
//  C7VoronoiOverlay.swift
//  Harbeth
//
//  Created by Condy on 2022/3/1.
//

import Foundation
import Metal

/// 泰森多边形叠加，使用预乘 source-over；alpha 为零时保持输入。
public struct C7VoronoiOverlay: C7MetalCommandEncodingProtocol, TemporaryTextureRequirementProviding {
    public var time: Float = 0.5
    public var alpha: Float = 0.05
    public var iResolution: C7Point2D = .center

    public var modifier: ModifierEnum { .metalCommand(label: "C7VoronoiOverlay") }
    public var factors: [Float] {
        [time.isFinite ? time : 0, alpha.isFinite ? min(max(alpha, 0), 1) : 0,
         iResolution.x.isFinite && iResolution.x > 0 ? max(iResolution.x, 0.000001) : 0.5,
         iResolution.y.isFinite ? iResolution.y : 0.5]
    }
    public var memoryAccessPattern: MemoryAccessPattern { .point }
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .premultiplied, precision: .float32,
              samplingFootprint: .point, coordinateDependency: .fullImage, globalDependency: .imageDimensions)
    }
    public var kernelOutputContract: RenderOutputContract { .init(alpha: .premultiplied) }

    public init(time: Float = 0.5, alpha: Float = 0.05) { self.time = time; self.alpha = alpha }
    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }
    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        try encode(context: context, maximumTemporaryBytes: temporaryByteLimit)
    }

    // 小图、非半精度目标和过密格点保留直接计算，避免两阶段调度的额外开销。
    func fieldSide(width: Int, height: Int, maximumTemporaryBytes: Int) -> Int? {
        guard width >= 512, height >= 512, maximumTemporaryBytes > 0, factors[1] > 0 else { return nil }
        let cells = ceil(8 / Double(factors[2])) + 4
        guard cells <= 512 else { return nil }
        let side = Int(cells)
        return side * side <= maximumTemporaryBytes / 16 ? side : nil
    }

    func encode(context: MetalCommandEncodingContext, maximumTemporaryBytes: Int) throws -> MTLTexture {
        let runtime = HarbethContext.shared, source = context.sourceTexture, destination = context.destinationTexture
        guard context.device === runtime.device else { throw HarbethError.configurationInvalid("格点编码时设备发生变化") }
        guard source.pixelFormat == .rgba16Float, destination.pixelFormat == source.pixelFormat,
              source.width == destination.width, source.height == destination.height,
              source.textureType == .type2D, source.arrayLength == 1, source.sampleCount == 1,
              let side = fieldSide(width: source.width, height: source.height, maximumTemporaryBytes: maximumTemporaryBytes),
              !hasKernelOverride(runtime) else { return try direct(context) }
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "voronoiBuildCells", librarySource: .harbethFramework)
        let pipeline = try context.environment.makeComputePipelineState(identity)
        let bytes = side * side * 16, budget = runtime.voronoiCellBudget
        guard budget.reserve(bytes, limit: maximumTemporaryBytes) else { return try direct(context) }
        let lease: TextureLease
        do {
            lease = try TextureLoader.makeTextureLease(width: side, height: side, options: [
                .texturePixelFormat: MTLPixelFormat.rgba32Float, .textureStorageMode: MTLStorageMode.private,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
            ], identifier: "VoronoiCells")
        } catch {
            budget.release(bytes)
            return try direct(context)
        }
        // GPU 完成或未提交缓冲区销毁后才释放额度和租约；purge 不撤销在途表面。
        let lifetime = TextureLease(texture: lease.texture) { lease.release(); budget.release(bytes) }
        context.commandBuffer.addCompletedHandler { _ in lifetime.release() }
        guard let encoder = context.commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(lease.texture, index: 0)
        var phase = factors[0]
        encoder.setBytes(&phase, length: MemoryLayout<Float>.size, index: 0)
        encoder.dispatchThreads(MTLSize(width: side, height: side, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        encoder.endEncoding()
        return try VoronoiPass(factors: factors, field: lease.texture).applyAtTexture(
            form: source, to: destination, for: context.commandBuffer)
    }

    func temporaryTextureRequirement(inputSize: C7Size) -> (bytes: Int, count: Int) {
        guard !hasKernelOverride(HarbethContext.shared),
              let side = fieldSide(width: inputSize.width, height: inputSize.height, maximumTemporaryBytes: temporaryByteLimit) else { return (0, 0) }
        return (side * side * 16, 1)
    }
    private var temporaryByteLimit: Int { min(4 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 4) }
    private func direct(_ context: MetalCommandEncodingContext) throws -> MTLTexture {
        try VoronoiPass(factors: factors, field: nil).applyAtTexture(
            form: context.sourceTexture, to: context.destinationTexture, for: context.commandBuffer)
    }
    private func hasKernelOverride(_ runtime: HarbethContext) -> Bool {
        (runtime.runtimeDevice.externalLibraries() + [runtime.runtimeDevice.defaultLibrary].compactMap { $0 }).contains {
            $0.makeFunction(name: "C7VoronoiOverlay") != nil
        }
    }
}

private struct VoronoiPass: C7FilterProtocol {
    let factors: [Float]
    let field: MTLTexture?
    var modifier: ModifierEnum { .compute(kernel: field == nil ? "C7VoronoiOverlay" : "C7VoronoiOverlayField") }
    var computeKernelLibrarySource: KernelLibrarySource { field == nil ? .automatic : .harbethFramework }
    var otherInputTextures: C7InputTextures { field.map { [$0] } ?? [] }
    var memoryAccessPattern: MemoryAccessPattern { .point }
}

final class VoronoiCellBudget: ContextTransientResource, @unchecked Sendable {
    private let lock = NSLock()
    private var storageBytes = 0
    var usedBytes: Int { lock.lock(); defer { lock.unlock() }; return storageBytes }
    func reserve(_ bytes: Int, limit: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard bytes > 0, bytes <= limit, storageBytes <= limit - bytes else { return false }
        storageBytes += bytes
        return true
    }
    func release(_ bytes: Int) { lock.lock(); storageBytes -= bytes; lock.unlock() }
    func purge() { }
}
