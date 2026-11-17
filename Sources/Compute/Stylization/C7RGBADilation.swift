// 由 Condy 维护。单方向通道最大值，重负载复用有界 MPS 后端。
import Foundation
import MetalPerformanceShaders

public struct C7RGBADilation: C7MetalCommandEncodingProtocol, TemporaryTextureRequirementProviding {
    public var pixelRadius: Int = 3
    public var vertical: Bool = false
    public var modifier: ModifierEnum {
        pixelRadius.magnitude >= 63 ? .metalCommand(label: "C7RGBADilation") : .compute(kernel: "C7RGBADilation")
    }
    public var factors: [Float] { [Float(pixelRadius.magnitude), vertical ? 1 : 0] }
    public var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
    public var destinationTextureContract: FilterDestinationTextureContract { .init(aliasingPolicy: .requiredDistinct) }
    public var kernelPixelContract: KernelPixelContract {
        .init(precision: .float32, dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .dynamic)
    }
    public init(pixelRadius: Int = 3) { self.pixelRadius = pixelRadius }
    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }
    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        try encode(context: context, maximumTemporaryBytes: min(128 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 3))
    }
    static func prefersMPS(width: Int, height: Int, radius: UInt, maximumTemporaryBytes: Int) -> Bool {
        guard radius >= 63, width > 0, height > 0, maximumTemporaryBytes > 0,
              width <= maximumTemporaryBytes / 16 / height else { return false }
        return width * height >= 1024 * 1024
    }
    func encode(context: MetalCommandEncodingContext, maximumTemporaryBytes: Int) throws -> MTLTexture {
        let source = context.sourceTexture, destination = context.destinationTexture, runtime = HarbethContext.shared
        guard context.device === runtime.device else { throw HarbethError.configurationInvalid("膨胀编码时设备发生变化") }
        let radius = min(pixelRadius.magnitude, UInt(max((vertical ? source.height : source.width) - 1, 0)))
        guard Self.prefersMPS(width: source.width, height: source.height, radius: radius, maximumTemporaryBytes: maximumTemporaryBytes),
              [.rgba8Unorm, .bgra8Unorm, .rgba16Float].contains(source.pixelFormat), source.pixelFormat == destination.pixelFormat,
              source.textureType == .type2D, source.arrayLength == 1, source.sampleCount == 1,
              source.width == destination.width, source.height == destination.height,
              MPSSupportsMTLDevice(context.device), !hasKernelOverride(runtime) else { return try direct(context) }
        let bytes = source.width * source.height * 16, budget = runtime.morphologyScratchBudget
        guard budget.reserve(bytes, limit: maximumTemporaryBytes) else { return try direct(context) }
        let identity = runtime.makeDerivedResourceIdentity(domain: .mask, namespace: "harbeth.rgba-dilation.area-max",
            fingerprint: "\(ObjectIdentifier(context.device))|\(radius)|\(vertical)")
        let box: AreaMaximumKernelBox
        if let cached = runtime.cachedDerivedObject(for: identity) as? AreaMaximumKernelBox { box = cached }
        else {
            box = AreaMaximumKernelBox(radius: Int(radius), vertical: vertical, device: context.device)
            runtime.storeDerivedObject(box, byteCost: 1, for: identity)
        }
        // 内核与保守额度持有到命令完成，未提交缓冲区销毁也能释放。
        let lifetime = TextureLease(texture: destination) { withExtendedLifetime(box) { budget.release(bytes) } }
        context.commandBuffer.addCompletedHandler { _ in lifetime.release() }
        return box.encode(context)
    }
    func temporaryTextureRequirement(inputSize: C7Size) -> (bytes: Int, count: Int) {
        guard inputSize.width > 0, inputSize.height > 0 else { return (0,0) }
        let w = inputSize.width, h = inputSize.height, runtime = HarbethContext.shared
        let limit = min(128 * 1024 * 1024, runtime.texturePool.byteLimit / 3)
        let radius = min(pixelRadius.magnitude, UInt(max((vertical ? h : w) - 1, 0)))
        guard Self.prefersMPS(width: w, height: h, radius: radius, maximumTemporaryBytes: limit),
              MPSSupportsMTLDevice(runtime.device), !hasKernelOverride(runtime) else { return (0,0) }
        return (w * h * 16, 1)
    }
    private func direct(_ context: MetalCommandEncodingContext) throws -> MTLTexture {
        try DilationDirectFilter(factors: factors).applyAtTexture(form: context.sourceTexture, to: context.destinationTexture, for: context.commandBuffer)
    }
    private func hasKernelOverride(_ runtime: HarbethContext) -> Bool {
        (runtime.runtimeDevice.externalLibraries() + [runtime.runtimeDevice.defaultLibrary].compactMap { $0 }).contains {
            $0.makeFunction(name: "C7RGBADilation") != nil
        }
    }
}
private struct DilationDirectFilter: C7FilterProtocol {
    let factors: [Float]
    var modifier: ModifierEnum { .compute(kernel: "C7RGBADilation") }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
}
private final class AreaMaximumKernelBox {
    private let lock = NSLock()
    private let kernel: MPSImageAreaMax
    init(radius: Int, vertical: Bool, device: MTLDevice) {
        kernel = MPSImageAreaMax(device: device, kernelWidth: vertical ? 1 : 2 * radius + 1, kernelHeight: vertical ? 2 * radius + 1 : 1)
        kernel.edgeMode = .clamp
    }
    func encode(_ context: MetalCommandEncodingContext) -> MTLTexture {
        lock.lock(); defer { lock.unlock() }
        kernel.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceTexture, destinationTexture: context.destinationTexture)
        return context.destinationTexture
    }
}
