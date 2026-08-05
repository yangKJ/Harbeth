//
//  KernelPixelContract.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation

/// Kernel 对扩展动态范围像素的处理方式。
public enum KernelDynamicRangeBehavior: String, Sendable, Codable, Equatable, Hashable {
    /// 尚未证明，HDR 或 EDR 执行器必须保守处理。
    case unspecified
    /// 保留负值和大于 1 的扩展范围数据。
    case preservesExtendedRange
    /// 把颜色限制到 0...1。
    case clampsToUnitRange
    /// 明确完成到 SDR 的 tone mapping。
    case toneMapsToSDR
    /// 明确完成到线性 EDR 的 tone mapping。
    case toneMapsToEDR
    /// 明确完成到 HDR 的 tone mapping。
    case toneMapsToHDR

    public var isExtendedRangeSafe: Bool {
        switch self {
        case .preservesExtendedRange, .toneMapsToEDR, .toneMapsToHDR:
            return true
        case .unspecified, .clampsToUnitRange, .toneMapsToSDR:
            return false
        }
    }
}

/// Kernel 读取纹理坐标的方式。
public enum KernelCoordinateDependency: String, Sendable, Codable, Equatable, Hashable {
    /// 只依赖当前局部区域内的相对坐标。
    case local
    /// 依赖输入纹理绝对坐标。
    case absoluteInput
    /// 依赖显式几何或投影变换后的坐标。
    case transformed
    /// 依赖整张图的尺寸或全局坐标。
    case fullImage
}

/// Kernel 对全图信息的依赖。
public enum KernelGlobalDependency: String, Sendable, Codable, Equatable, Hashable {
    case none
    case imageDimensions
    case imageStatistics
    case externalState
}

/// Kernel 是否允许进入真实 pass fusion。
public enum KernelFusionPolicy: String, Sendable, Codable, Equatable, Hashable {
    case disabled
    case pointwise
}

/// 像素合同的证据来源。
public enum KernelPixelContractEvidence: String, Sendable, Codable, Equatable, Hashable {
    /// Kernel 作者明确声明了完整合同。
    case declared
    /// 旧 Kernel 尚未声明，只能使用保守回退值。
    case conservativeFallback
}

/// 单个 Kernel 的完整像素与区域执行合同。
///
/// 该类型属于滤镜 authoring 和 runtime support，不会形成第三条普通用户入口。
public struct KernelPixelContract: Sendable, Codable, Equatable, Hashable {
    public let inputColorSpace: ImageColorSpaceContract
    public let workingColorSpace: ImageColorSpaceContract
    public let outputColorSpace: ImageColorSpaceContract
    public let inputAlphaExpectation: ImageAlphaContract
    public let outputAlpha: ImageAlphaContract
    public let precision: PixelPrecision
    public let dynamicRangeBehavior: KernelDynamicRangeBehavior
    public let samplingFootprint: SamplingFootprint
    public let coordinateDependency: KernelCoordinateDependency
    public let globalDependency: KernelGlobalDependency
    public let isDeterministic: Bool
    public let requiresCPUReadback: Bool
    public let fusionPolicy: KernelFusionPolicy
    public let evidence: KernelPixelContractEvidence

    public init(
        inputColorSpace: ImageColorSpaceContract = .preserveInput,
        workingColorSpace: ImageColorSpaceContract = .preserveInput,
        outputColorSpace: ImageColorSpaceContract = .preserveInput,
        inputAlphaExpectation: ImageAlphaContract = .preserveInput,
        outputAlpha: ImageAlphaContract = .preserveInput,
        precision: PixelPrecision = .preserveInput,
        dynamicRangeBehavior: KernelDynamicRangeBehavior = .unspecified,
        samplingFootprint: SamplingFootprint,
        coordinateDependency: KernelCoordinateDependency = .local,
        globalDependency: KernelGlobalDependency = .none,
        isDeterministic: Bool = true,
        requiresCPUReadback: Bool = false,
        fusionPolicy: KernelFusionPolicy = .disabled,
        evidence: KernelPixelContractEvidence = .declared
    ) {
        self.inputColorSpace = inputColorSpace
        self.workingColorSpace = workingColorSpace
        self.outputColorSpace = outputColorSpace
        self.inputAlphaExpectation = inputAlphaExpectation
        self.outputAlpha = outputAlpha
        self.precision = precision
        self.dynamicRangeBehavior = dynamicRangeBehavior
        self.samplingFootprint = samplingFootprint
        self.coordinateDependency = coordinateDependency
        self.globalDependency = globalDependency
        self.isDeterministic = isDeterministic
        self.requiresCPUReadback = requiresCPUReadback
        self.fusionPolicy = fusionPolicy
        self.evidence = evidence
    }

    public var canAutoTile: Bool {
        samplingFootprint.canAutoTile && globalDependency == .none
    }

    public var isPointwiseFusionEligible: Bool {
        fusionPolicy == .pointwise
            && samplingFootprint == .point
            && globalDependency == .none
            && requiresCPUReadback == false
    }

    public var fingerprint: String {
        [
            "inputColor={\(inputColorSpace.fingerprint)}",
            "workingColor={\(workingColorSpace.fingerprint)}",
            "outputColor={\(outputColorSpace.fingerprint)}",
            "inputAlpha=\(inputAlphaExpectation.fingerprint)",
            "outputAlpha=\(outputAlpha.fingerprint)",
            "precision=\(precision.rawValue)",
            "dynamicRange=\(dynamicRangeBehavior.rawValue)",
            "footprint=\(samplingFootprint.fingerprint)",
            "coordinates=\(coordinateDependency.rawValue)",
            "global=\(globalDependency.rawValue)",
            "deterministic=\(isDeterministic ? 1 : 0)",
            "cpuReadback=\(requiresCPUReadback ? 1 : 0)",
            "fusion=\(fusionPolicy.rawValue)",
            "evidence=\(evidence.rawValue)"
        ].joined(separator: "|")
    }

    public static func conservative(samplingFootprint: SamplingFootprint) -> KernelPixelContract {
        let coordinateDependency: KernelCoordinateDependency = samplingFootprint == .global ? .fullImage : .local
        let globalDependency: KernelGlobalDependency = samplingFootprint == .global ? .imageDimensions : .none
        return KernelPixelContract(
            samplingFootprint: samplingFootprint,
            coordinateDependency: coordinateDependency,
            globalDependency: globalDependency,
            fusionPolicy: samplingFootprint == .point ? .pointwise : .disabled,
            evidence: .conservativeFallback
        )
    }

}

public extension C7FilterProtocol {
    /// 所有滤镜都有可检查的像素合同；没有明确证明的能力保持保守值。
    var kernelPixelContract: KernelPixelContract {
        if let pipeline = self as? C7FilterPipelineProtocol {
            let finalFilter = pipeline.makeFinalFilter(otherInputTextures: nil)
            return KernelPixelContract.combining(pipeline.pipelineFilters + [finalFilter].compactMap { $0 })
        }
        return .conservative(samplingFootprint: samplingFootprint)
    }
}

private extension KernelPixelContract {
    static func combining(_ filters: [C7FilterProtocol]) -> KernelPixelContract {
        guard let first = filters.first else {
            return .conservative(samplingFootprint: .dynamic)
        }
        let contracts = filters.map(\.kernelPixelContract)
        let footprint = contracts.map(\.samplingFootprint).reduce(first.samplingFootprint) { partial, next in
            partial.combined(with: next)
        }
        let dynamicRangeBehavior: KernelDynamicRangeBehavior
        if contracts.contains(where: { $0.dynamicRangeBehavior == .clampsToUnitRange }) {
            dynamicRangeBehavior = .clampsToUnitRange
        } else if contracts.allSatisfy({ $0.dynamicRangeBehavior.isExtendedRangeSafe }) {
            dynamicRangeBehavior = .preservesExtendedRange
        } else {
            dynamicRangeBehavior = .unspecified
        }
        return KernelPixelContract(
            inputColorSpace: contracts.first?.inputColorSpace ?? .preserveInput,
            workingColorSpace: contracts.first(where: { $0.workingColorSpace.preservesInput == false })?.workingColorSpace ?? .preserveInput,
            outputColorSpace: contracts.last?.outputColorSpace ?? .preserveInput,
            inputAlphaExpectation: contracts.first?.inputAlphaExpectation ?? .preserveInput,
            outputAlpha: contracts.last?.outputAlpha ?? .preserveInput,
            precision: contracts.map(\.precision).max(by: { $0.rank < $1.rank }) ?? .preserveInput,
            dynamicRangeBehavior: dynamicRangeBehavior,
            samplingFootprint: footprint,
            coordinateDependency: contracts.contains(where: { $0.coordinateDependency == .fullImage }) ? .fullImage : .local,
            globalDependency: contracts.first(where: { $0.globalDependency != .none })?.globalDependency ?? .none,
            isDeterministic: contracts.allSatisfy(\.isDeterministic),
            requiresCPUReadback: contracts.contains(where: \.requiresCPUReadback),
            fusionPolicy: contracts.allSatisfy(\.isPointwiseFusionEligible) ? .pointwise : .disabled,
            evidence: contracts.allSatisfy { $0.evidence == .declared } ? .declared : .conservativeFallback
        )
    }
}

private extension SamplingFootprint {
    func combined(with other: SamplingFootprint) -> SamplingFootprint {
        switch (self, other) {
        case (.global, _), (_, .global):
            return .global
        case (.dynamic, _), (_, .dynamic):
            return .dynamic
        case (.point, .point):
            return .point
        case (.neighborhood(let lhs), .neighborhood(let rhs)):
            return .neighborhood(radius: lhs + rhs)
        case (.point, .neighborhood(let radius)), (.neighborhood(let radius), .point):
            return .neighborhood(radius: radius)
        }
    }
}

private extension PixelPrecision {
    var rank: Int {
        switch self {
        case .preserveInput:
            return 0
        case .unorm8:
            return 1
        case .float16:
            return 2
        case .float32:
            return 3
        case .custom:
            return 4
        }
    }
}

private extension ImageAlphaContract {
    var fingerprint: String {
        switch self {
        case .opaque:
            return "opaque"
        case .premultiplied:
            return "premultiplied"
        case .nonPremultiplied:
            return "nonPremultiplied"
        case .preserveInput:
            return "preserveInput"
        case .forcePremultiply:
            return "forcePremultiply"
        case .forceUnpremultiply:
            return "forceUnpremultiply"
        }
    }
}
