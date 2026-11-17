// 由 Condy 创建于 2026/11/17。轮廓的保守平坦分类，仅服务内置执行路径。
import Foundation
import Metal

enum OutlineFlatClassification {
    static var byteLimit: Int { min(4 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 4) }

    static func requirement(width: Int, height: Int, thickness: Float, limit: Int) -> (bytes: Int, columns: Int, rows: Int)? {
        guard width >= 512, height >= 512, thickness.isFinite, thickness > 0, thickness <= 0.1, limit > 0 else { return nil }
        let radius = Int(thickness * Float(width))
        guard (8...20).contains(radius) else { return nil }
        let columns = (width + 15) / 16, rows = (height + 15) / 16
        guard columns <= limit / 4 / rows else { return nil }
        return (columns * rows * 4, columns, rows)
    }

    static func encode(
        commandBuffer: MTLCommandBuffer,
        textures: [MTLTexture],
        descriptor: KernelDescriptor,
        identity: KernelFunctionIdentity,
        maximumTemporaryBytes: Int? = nil
    ) throws -> MTLTexture? {
        // 自动加入的组特化也证明当前解析目标为内置函数；显式特化、外部覆盖和区域包装继续走原路径。
        guard textures.count == 2, descriptor.functionIdentity.primaryName == "C7StickerOutline",
              descriptor.functionIdentity.functionConstants.isEmpty, !identity.functionConstants.isEmpty,
              textures[0].pixelFormat == .rgba16Float, textures[1].pixelFormat == .rgba16Float,
              textures[0].width == textures[1].width, textures[0].height == textures[1].height,
              textures.allSatisfy({ $0.textureType == .type2D && $0.arrayLength == 1 && $0.sampleCount == 1 }) else { return nil }
        let bindings = descriptor.parameterBindings
        guard bindings.count == 3, Set(bindings.map(\.index)) == Set([0, 1, 2]), bindings.allSatisfy({ $0.stage == .compute }),
              case .float(let thickness) = bindings.first(where: { $0.index == 0 })!.value,
              case .float(let blur) = bindings.first(where: { $0.index == 1 })!.value,
              case .float4(let color) = bindings.first(where: { $0.index == 2 })!.value,
              blur.isFinite, (0...1).contains(blur), [color.x, color.y, color.z, color.w].allSatisfy(\.isFinite) else { return nil }
        let limit = maximumTemporaryBytes ?? byteLimit
        guard let size = requirement(width: textures[1].width, height: textures[1].height, thickness: thickness, limit: limit) else { return nil }
        let runtime = HarbethContext.shared
        guard runtime.device === commandBuffer.device else { throw HarbethError.configurationInvalid("轮廓分类时设备发生变化") }
        let classification = KernelFunctionIdentity(kind: .compute, primaryName: "outlineClassifyFlat", librarySource: .harbethFramework)
        let main = KernelFunctionIdentity(kind: .compute, primaryName: "C7StickerOutlineClassified", librarySource: .harbethFramework, functionConstants: identity.functionConstants)
        guard let classifyPipeline = try? runtime.makeComputePipelineState(identity: classification),
              let mainPipeline = try? runtime.makeComputePipelineState(identity: main),
              classifyPipeline.maxTotalThreadsPerThreadgroup >= 64, mainPipeline.maxTotalThreadsPerThreadgroup >= 256 else { return nil }
        let budget = runtime.outlineClassificationBudget
        guard budget.reserve(size.bytes, limit: limit) else { return nil }
        let lease: TextureLease
        do {
            lease = try TextureLoader.makeTextureLease(width: size.columns, height: size.rows, options: [
                .texturePixelFormat: MTLPixelFormat.r32Uint, .textureStorageMode: MTLStorageMode.private,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite]), .textureHazardTrackingMode: MTLHazardTrackingMode.tracked
            ], identifier: "OutlineFlatClassification")
        } catch {
            budget.release(size.bytes)
            return nil
        }
        let lifetime = TextureLease(texture: lease.texture) { lease.release(); budget.release(size.bytes) }
        commandBuffer.addCompletedHandler { _ in lifetime.release() }
        guard let classify = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
        classify.label = "Outline flat classification"
        classify.setComputePipelineState(classifyPipeline)
        classify.setTexture(lease.texture, index: 0); classify.setTexture(textures[1], index: 1)
        var radius = UInt32(Int(thickness * Float(textures[1].width)))
        classify.setBytes(&radius, length: MemoryLayout<UInt32>.size, index: 0)
        classify.dispatchThreadgroups(MTLSize(width: size.columns, height: size.rows, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
        classify.endEncoding()
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
        encoder.label = "Outline classified search"
        encoder.setComputePipelineState(mainPipeline)
        encoder.setTexture(textures[0], index: 0); encoder.setTexture(textures[1], index: 1); encoder.setTexture(lease.texture, index: 2)
        do { try KernelBindingEncoder.encode(bindings, stage: .compute, on: encoder) }
        catch { encoder.endEncoding(); throw error }
        var halfOutput: Float = 1
        encoder.setBytes(&halfOutput, length: MemoryLayout<Float>.size, index: 3)
        encoder.dispatchThreadgroups(MTLSize(width: size.columns, height: size.rows, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding()
        return textures[0]
    }
}

final class OutlineClassificationBudget: ContextTransientResource, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = 0
    var usedBytes: Int { lock.lock(); defer { lock.unlock() }; return bytes }
    func reserve(_ count: Int, limit: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard count > 0, count <= limit, bytes <= limit - count else { return false }
        bytes += count
        return true
    }
    func release(_ count: Int) { lock.lock(); bytes -= count; lock.unlock() }
    func purge() { }
}
