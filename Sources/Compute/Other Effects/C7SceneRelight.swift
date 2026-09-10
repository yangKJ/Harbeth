//
//  C7SceneRelight.swift
//  Harbeth
//
//  Created by Condy on 2026/7/31.
//

import Foundation
import Metal

/// 场景布光使用的通用灯光类型。
public enum SceneLightKind: Int, Sendable, Codable, Equatable, Hashable {
    /// 从画布中的三维位置向场景发光。
    case point = 0
    /// 带方向和锥角约束的位置光。
    case spot = 1
    /// 不随位置衰减的平行光。
    case directional = 2
    /// 依据视线与深度法线夹角形成的轮廓光。
    case rim = 3
}

/// 单盏 2.5D 场景灯的底层描述。
///
/// 坐标约定：
/// - `position.x/y` 使用完整输出画布的归一化坐标，允许灯位落在画布之外；
/// - `position.z` 与归一化深度共用场景尺度，正方向朝向观察者；
/// - `direction` 表示光线传播方向；
/// - `color` 必须是线性 RGB，不在该 primitive 内执行 transfer-function 转换。
public struct SceneLightDescriptor: Sendable, Codable, Equatable, Hashable {
    public let kind: SceneLightKind
    public let position: SIMD3<Float>
    public let direction: SIMD3<Float>
    public let color: SIMD3<Float>
    public let intensity: Float
    public let radius: Float
    public let softness: Float
    public let coneAngleDegrees: Float
    public let falloff: Float
    public let isEnabled: Bool

    public init(
        kind: SceneLightKind = .point,
        position: SIMD3<Float> = SIMD3<Float>(0.5, 0.5, 1.5),
        direction: SIMD3<Float> = SIMD3<Float>(0, 0, -1),
        color: SIMD3<Float> = SIMD3<Float>(repeating: 1),
        intensity: Float = 1,
        radius: Float = 1,
        softness: Float = 0.5,
        coneAngleDegrees: Float = 45,
        falloff: Float = 1,
        isEnabled: Bool = true
    ) {
        self.kind = kind
        self.position = SIMD3<Float>(
            Self.finiteClamped(position.x, to: -8...9, fallback: 0.5),
            Self.finiteClamped(position.y, to: -8...9, fallback: 0.5),
            Self.finiteClamped(position.z, to: -8...9, fallback: 1.5)
        )
        self.color = SIMD3<Float>(
            Self.finiteClamped(color.x, to: 0...8, fallback: 1),
            Self.finiteClamped(color.y, to: 0...8, fallback: 1),
            Self.finiteClamped(color.z, to: 0...8, fallback: 1)
        )
        self.direction = Self.normalizedDirection(direction)
        self.intensity = Self.finiteClamped(intensity, to: 0...8, fallback: 0)
        self.radius = Self.finiteClamped(radius, to: 0.001...4, fallback: 1)
        self.softness = Self.finiteClamped(softness, to: 0...1, fallback: 0.5)
        self.coneAngleDegrees = Self.finiteClamped(coneAngleDegrees, to: 1...179, fallback: 45)
        self.falloff = Self.finiteClamped(falloff, to: 0...16, fallback: 1)
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decode(SceneLightKind.self, forKey: .kind),
            position: try container.decode(SIMD3<Float>.self, forKey: .position),
            direction: try container.decode(SIMD3<Float>.self, forKey: .direction),
            color: try container.decode(SIMD3<Float>.self, forKey: .color),
            intensity: try container.decode(Float.self, forKey: .intensity),
            radius: try container.decode(Float.self, forKey: .radius),
            softness: try container.decode(Float.self, forKey: .softness),
            coneAngleDegrees: try container.decode(Float.self, forKey: .coneAngleDegrees),
            falloff: try container.decode(Float.self, forKey: .falloff),
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(position, forKey: .position)
        try container.encode(direction, forKey: .direction)
        try container.encode(color, forKey: .color)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(radius, forKey: .radius)
        try container.encode(softness, forKey: .softness)
        try container.encode(coneAngleDegrees, forKey: .coneAngleDegrees)
        try container.encode(falloff, forKey: .falloff)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    static let disabled = SceneLightDescriptor(intensity: 0, isEnabled: false)

    var packedValues: [Float] {
        [
            Float(kind.rawValue), isEnabled ? 1 : 0,
            position.x, position.y, position.z,
            direction.x, direction.y, direction.z,
            color.x, color.y, color.z,
            intensity, radius, softness,
            coneAngleDegrees * .pi / 180,
            falloff
        ]
    }

    private static func finiteClamped(_ value: Float, to range: ClosedRange<Float>, fallback: Float) -> Float {
        guard value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }

    private static func normalizedDirection(_ value: SIMD3<Float>) -> SIMD3<Float> {
        guard value.x.isFinite, value.y.isFinite, value.z.isFinite else {
            return SIMD3<Float>(0, 0, -1)
        }
        let lengthSquared = value.x * value.x + value.y * value.y + value.z * value.z
        guard lengthSquared > 0.000_001 else { return SIMD3<Float>(0, 0, -1) }
        return value / sqrt(lengthSquared)
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case position
        case direction
        case color
        case intensity
        case radius
        case softness
        case coneAngleDegrees
        case falloff
        case isEnabled
    }
}

/// 深度感知场景布光的全局描述。
///
/// 该描述只接受最多三盏灯。`ambient` 与每盏灯先构成新的照明增益，
/// 再通过 `originalLight` 与原始照明增益 1 混合，避免底层隐式加入产品预设。
public struct SceneRelightDescriptor: Sendable, Codable, Equatable, Hashable {
    public static let maximumLightCount = 3

    public let lights: [SceneLightDescriptor]
    public let ambient: Float
    public let originalLight: Float
    public let normalStrength: Float
    public let depthScale: Float
    public let highlightRolloff: Float
    public let confidenceFloor: Float

    public init(
        lights: [SceneLightDescriptor] = [],
        ambient: Float = 1,
        originalLight: Float = 0,
        normalStrength: Float = 1,
        depthScale: Float = 0.5,
        highlightRolloff: Float = 1,
        confidenceFloor: Float = 0
    ) throws {
        guard lights.count <= Self.maximumLightCount else {
            throw HarbethError.sceneRelightTooManyLights(maximum: Self.maximumLightCount, actual: lights.count)
        }
        self.init(
            validatedLights: lights,
            ambient: ambient,
            originalLight: originalLight,
            normalStrength: normalStrength,
            depthScale: depthScale,
            highlightRolloff: highlightRolloff,
            confidenceFloor: confidenceFloor
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lights = try container.decode([SceneLightDescriptor].self, forKey: .lights)
        do {
            try self.init(
                lights: lights,
                ambient: try container.decode(Float.self, forKey: .ambient),
                originalLight: try container.decode(Float.self, forKey: .originalLight),
                normalStrength: try container.decode(Float.self, forKey: .normalStrength),
                depthScale: try container.decode(Float.self, forKey: .depthScale),
                highlightRolloff: try container.decode(Float.self, forKey: .highlightRolloff),
                confidenceFloor: try container.decode(Float.self, forKey: .confidenceFloor)
            )
        } catch let error as HarbethError {
            guard case .sceneRelightTooManyLights = error else { throw error }
            throw DecodingError.dataCorruptedError(
                forKey: .lights,
                in: container,
                debugDescription: "Invalid scene-relight light count: \(error)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lights, forKey: .lights)
        try container.encode(ambient, forKey: .ambient)
        try container.encode(originalLight, forKey: .originalLight)
        try container.encode(normalStrength, forKey: .normalStrength)
        try container.encode(depthScale, forKey: .depthScale)
        try container.encode(highlightRolloff, forKey: .highlightRolloff)
        try container.encode(confidenceFloor, forKey: .confidenceFloor)
    }

    public static let identity = SceneRelightDescriptor(
        validatedLights: [],
        ambient: 1,
        originalLight: 0,
        normalStrength: 1,
        depthScale: 0.5,
        highlightRolloff: 1,
        confidenceFloor: 0
    )

    private init(
        validatedLights: [SceneLightDescriptor],
        ambient: Float,
        originalLight: Float,
        normalStrength: Float,
        depthScale: Float,
        highlightRolloff: Float,
        confidenceFloor: Float
    ) {
        self.lights = validatedLights
        self.ambient = Self.finiteClamped(ambient, to: 0...4, fallback: 1)
        self.originalLight = Self.finiteClamped(originalLight, to: 0...1, fallback: 1)
        self.normalStrength = Self.finiteClamped(normalStrength, to: 0...8, fallback: 1)
        self.depthScale = Self.finiteClamped(depthScale, to: 0...4, fallback: 0.5)
        self.highlightRolloff = Self.finiteClamped(highlightRolloff, to: 0...8, fallback: 1)
        self.confidenceFloor = Self.finiteClamped(confidenceFloor, to: 0...1, fallback: 0)
    }

    func packedValues(hasConfidencePlane: Bool) -> [Float] {
        var values: [Float] = [
            1, Float(lights.count), ambient, originalLight,
            normalStrength, depthScale, highlightRolloff, confidenceFloor,
            hasConfidencePlane ? 1 : 0,
            0, 0, 0, 0, 0, 0, 0
        ]
        let paddedLights = lights + Array(
            repeating: SceneLightDescriptor.disabled,
            count: Self.maximumLightCount - lights.count
        )
        values.append(contentsOf: paddedLights.flatMap(\.packedValues))
        return values
    }

    private static func finiteClamped(_ value: Float, to range: ClosedRange<Float>, fallback: Float) -> Float {
        guard value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }

    private enum CodingKeys: String, CodingKey {
        case lights
        case ambient
        case originalLight
        case normalStrength
        case depthScale
        case highlightRolloff
        case confidenceFloor
    }
}

/// 依赖归一化深度平面的 2.5D 场景布光 primitive。
///
/// 直接执行时必须使用 `init(descriptor:depthTexture:confidenceTexture:)`。
/// 深度约定为近处 1、远处 0，并与输入纹理使用同一逻辑画布和方向。
/// 低分辨率 depth/confidence 会按完整画布 UV 做 invalid-aware 双线性采样；
/// 无效 texel 不参与权重归一化，只有当前采样完全没有有效贡献时才保留原像素。
/// confidence 可省略；底层仍会用 depth 作为不读取的占位纹理，保持
/// source/depth/confidence 三输入的固定 texture ABI。
///
/// `deferred` 只用于区域执行器或 recipe graph 装配。该模式本身不是完整的
/// 可执行滤镜，contextual execution 必须把 depth 与 confidence（或占位平面）
/// 分别注入 auxiliary index 0/1。调用方可通过 `requiresDeferredDepthBinding`
/// 明确诊断该状态，不能把无深度输入静默降级成普通颜色滤镜。
public struct C7SceneRelight: C7FilterProtocol {
    public static let parameterCount = 64
    public static let requiredDeferredAuxiliaryTextureCount = 2

    public let descriptor: SceneRelightDescriptor
    public let requiresDeferredDepthBinding: Bool
    public let expectsConfidencePlane: Bool

    private let depthTexture: MTLTexture?
    private let confidenceTexture: MTLTexture?

    public var modifier: ModifierEnum {
        .compute(kernel: "C7SceneRelight")
    }

    public var otherInputTextures: C7InputTextures {
        guard let depthTexture else { return [] }
        return [depthTexture, confidenceTexture ?? depthTexture]
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "sceneRelightParameters",
                index: 0,
                stage: .compute,
                value: .floatArray(descriptor.packedValues(hasConfidencePlane: expectsConfidencePlane))
            )
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    public var kernelPixelContract: KernelPixelContract {
        let linearRGB = ImageColorSpaceContract(
            name: "linearRGB",
            preservesInput: false,
            gamut: .preserveInput,
            transferFunction: .linear
        )
        return KernelPixelContract(
            inputColorSpace: linearRGB,
            workingColorSpace: linearRGB,
            outputColorSpace: linearRGB,
            inputAlphaExpectation: .preserveInput,
            outputAlpha: .preserveInput,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(radius: 1),
            coordinateDependency: .fullImage,
            globalDependency: .none,
            fusionPolicy: .disabled
        )
    }

    public var kernelResourceIdentity: String? {
        guard let depthTexture else {
            return "sceneRelight|binding=deferred|confidence=\(expectsConfidencePlane ? 1 : 0)|requiredAuxiliaryInputs=2"
        }
        let confidence = confidenceTexture ?? depthTexture
        return [
            "sceneRelight",
            "binding=direct",
            "depth=\(ObjectIdentifier(depthTexture).hashValue)",
            "confidence=\(ObjectIdentifier(confidence).hashValue)",
            "hasConfidence=\(expectsConfidencePlane ? 1 : 0)"
        ].joined(separator: "|")
    }

    public var parameterDescription: [String: Any] {
        [
            "bindingMode": requiresDeferredDepthBinding ? "deferred" : "direct",
            "expectsConfidencePlane": expectsConfidencePlane,
            "lightCount": descriptor.lights.count,
            "requiredDeferredAuxiliaryTextureCount": requiresDeferredDepthBinding ? Self.requiredDeferredAuxiliaryTextureCount : 0
        ]
    }

    public init(descriptor: SceneRelightDescriptor, depthTexture: MTLTexture, confidenceTexture: MTLTexture? = nil) {
        self.descriptor = descriptor
        self.depthTexture = depthTexture
        self.confidenceTexture = confidenceTexture
        self.requiresDeferredDepthBinding = false
        self.expectsConfidencePlane = confidenceTexture != nil
    }

    /// 创建等待 contextual executor 注入深度平面的描述节点。
    ///
    /// 即使 `hasConfidencePlane` 为 false，执行器仍必须在 auxiliary index 1
    /// 绑定合法占位纹理，以维持固定 texture ABI；shader 不会读取该占位平面。
    public static func deferred(_ descriptor: SceneRelightDescriptor, hasConfidencePlane: Bool = true) -> Self {
        C7SceneRelight(
            descriptor: descriptor,
            depthTexture: nil,
            confidenceTexture: nil,
            requiresDeferredDepthBinding: true,
            expectsConfidencePlane: hasConfidencePlane
        )
    }

    private init(
        descriptor: SceneRelightDescriptor,
        depthTexture: MTLTexture?,
        confidenceTexture: MTLTexture?,
        requiresDeferredDepthBinding: Bool,
        expectsConfidencePlane: Bool
    ) {
        self.descriptor = descriptor
        self.depthTexture = depthTexture
        self.confidenceTexture = confidenceTexture
        self.requiresDeferredDepthBinding = requiresDeferredDepthBinding
        self.expectsConfidencePlane = expectsConfidencePlane
    }
}
