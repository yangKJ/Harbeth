//
//  C7Morphology.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation
import MetalPerformanceShaders

/// 形态学操作滤镜（腐蚀和膨胀）
/// Morphological operation filter (corrosion and expansion)
public struct C7Morphology: C7MetalCommandEncodingProtocol, TemporaryTextureRequirementProviding {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 1, max: 9, value: 3)
    
    public enum OperationType {
        case erosion, dilation
    }
    
    public let operation: OperationType
    
    /// The size of structural elements.
    @Clamping(range.min...range.max) public var kernelSize: Float = range.value
    
    public var modifier: ModifierEnum {
        normalizedKernelSize >= 7 ? .metalCommand(label: "C7Morphology") : .compute(kernel: "C7Morphology")
    }
    
    public var factors: [Float] {
        let operationValue: Float = operation == .erosion ? 0.0 : 1.0
        return [operationValue, Float(normalizedKernelSize)]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: normalizedKernelSize / 2)
    }

    /// 形态学 kernel 统一为 1...9 的奇数；偶数向上取整到下一个奇数。
    /// 例如 0、1、2、4、10 分别归一化为 1、1、3、5、9。
    public var normalizedKernelSize: Int {
        let rounded = kernelSize.isFinite ? Int(min(max(kernelSize, 1), 9).rounded()) : 1
        let clamped = min(max(rounded, 1), 9)
        if clamped.isMultiple(of: 2) {
            return min(clamped + 1, 9)
        }
        return clamped
    }
    
    public init(operation: OperationType, kernelSize: Float = range.value) {
        self.operation = operation
        self.kernelSize = kernelSize
    }

    public var destinationTextureContract: FilterDestinationTextureContract { .init(aliasingPolicy: .requiredDistinct) }

    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }

    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        let limit = min(128 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 3)
        return try encode(context: context, maximumTemporaryBytes: limit)
    }

    static func prefersMPS(
        width: Int,
        height: Int,
        kernelSize: Int,
        maximumTemporaryBytes: Int
    ) -> Bool {
        guard width > 0, height > 0, kernelSize >= 7, maximumTemporaryBytes > 0,
              width <= maximumTemporaryBytes / 16 / height else { return false }
        return width * height >= 512 * 512
    }

    func encode(context: MetalCommandEncodingContext, maximumTemporaryBytes: Int) throws -> MTLTexture {
        let source = context.sourceTexture, destination = context.destinationTexture
        let runtime = HarbethContext.shared
        let formats: [MTLPixelFormat] = [.rgba8Unorm, .bgra8Unorm, .rgba16Float]
        guard runtime.device === context.device else { throw HarbethError.configurationInvalid("Morphology device changed during encoding.") }
        guard Self.prefersMPS(width: source.width, height: source.height, kernelSize: normalizedKernelSize,
                              maximumTemporaryBytes: maximumTemporaryBytes), MPSSupportsMTLDevice(context.device),
              formats.contains(source.pixelFormat), source.pixelFormat == destination.pixelFormat,
              source.textureType == .type2D, source.arrayLength == 1, source.sampleCount == 1,
              source.width == destination.width, source.height == destination.height else { return try direct(context) }
        // 保留已注册同名内核的解析优先级，不能静默绕过开发者的替换。
        guard !hasKernelOverride(runtime) else { return try direct(context) }
        let bytes = source.width * source.height * 16
        let budget = runtime.morphologyScratchBudget
        guard budget.reserve(bytes, limit: maximumTemporaryBytes) else { return try direct(context) }
        let identity = runtime.makeDerivedResourceIdentity(domain: .mask, namespace: "harbeth.morphology.kernel",
            fingerprint: "\(ObjectIdentifier(context.device))|\(operation == .erosion ? 0 : 1)|\(normalizedKernelSize)")
        let kernel: MorphologyKernelBox
        if let cached = runtime.cachedDerivedObject(for: identity) as? MorphologyKernelBox {
            kernel = cached
        } else {
            kernel = MorphologyKernelBox(operation: operation, size: normalizedKernelSize, device: context.device)
            runtime.storeDerivedObject(kernel, byteCost: 1, for: identity)
        }
        // 闭包持有内核和额度，直到 GPU 完成或未提交缓冲区销毁。
        let lifetime = TextureLease(texture: destination) {
            withExtendedLifetime(kernel) { budget.release(bytes) }
        }
        context.commandBuffer.addCompletedHandler { _ in lifetime.release() }
        return try kernel.encode(context)
    }

    func temporaryTextureRequirement(inputSize: C7Size) -> (bytes: Int, count: Int) {
        let w = Int(inputSize.width), h = Int(inputSize.height)
        let limit = min(128 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 3)
        guard Self.prefersMPS(width: w, height: h, kernelSize: normalizedKernelSize, maximumTemporaryBytes: limit),
              MPSSupportsMTLDevice(HarbethContext.shared.device), !hasKernelOverride(HarbethContext.shared) else { return (0, 0) }
        // MPS 的不透明临时分配按一张全尺寸 RGBA32Float 表面保守准入。
        return (w * h * 16, 1)
    }

    private func direct(_ context: MetalCommandEncodingContext) throws -> MTLTexture {
        try MorphologyDirectFilter(factors: factors).applyAtTexture(form: context.sourceTexture, to: context.destinationTexture, for: context.commandBuffer)
    }

    private func hasKernelOverride(_ runtime: HarbethContext) -> Bool {
        let libraries = runtime.runtimeDevice.externalLibraries() + [runtime.runtimeDevice.defaultLibrary].compactMap { $0 }
        return libraries.contains { $0.makeFunction(name: "C7Morphology") != nil }
    }
}

private struct MorphologyDirectFilter: C7FilterProtocol {
    let factors: [Float]
    var modifier: ModifierEnum { .compute(kernel: "C7Morphology") }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
}

private final class MorphologyKernelBox {
    private let lock = NSLock()
    private let filter: MPSMorphology
    init(operation: C7Morphology.OperationType, size: Int, device: MTLDevice) {
        filter = MPSMorphology(operation: operation == .erosion ? .erode : .dilate, kernelSize: size, device: device)
    }
    func encode(_ context: MetalCommandEncodingContext) throws -> MTLTexture {
        lock.lock()
        defer { lock.unlock() }
        return try filter.encode(commandBuffer: context.commandBuffer, textures: [context.destinationTexture, context.sourceTexture])
    }
}

final class MorphologyScratchBudget: ContextTransientResource, @unchecked Sendable {
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
    func purge() { }
}
