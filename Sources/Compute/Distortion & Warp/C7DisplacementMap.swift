//
//  C7DisplacementMap.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation
import Metal

/// Displacement texture 的 RG 编码方式。
public enum DisplacementEncoding: Int, Sendable, Codable, CaseIterable {
    /// RG 直接表达有符号位移，零值表示不移动。
    case signed = 0
    /// RG 的 0.5 表示不移动，0...1 映射为 -1...1。
    case normalized = 1
}

/// Displacement 数值的空间单位。
public enum DisplacementUnit: Int, Sendable, Codable, CaseIterable {
    case pixels = 0
    case normalized = 1
}

/// 使用外部 displacement/flow texture 执行单帧图像变形。
///
/// Harbeth 只消费已经生成的位移场；光流估计、跨帧调度和媒体生命周期不属于该 primitive。
public struct C7DisplacementMap: C7FilterProtocol, SamplerAdaptableFilter {

    public let displacementTexture: MTLTexture
    public let confidenceTexture: MTLTexture?
    public var scale: Float
    public var unit: DisplacementUnit
    public var encoding: DisplacementEncoding
    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode

    public var modifier: ModifierEnum {
        .compute(kernel: "C7DisplacementMap")
    }

    public var otherInputTextures: C7InputTextures {
        [displacementTexture, confidenceTexture ?? displacementTexture]
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "scale", index: 0, stage: .compute, value: .float(scale.isFinite ? scale : 1)),
            KernelParameterBinding(name: "unit", index: 1, stage: .compute, value: .int(unit.rawValue)),
            KernelParameterBinding(name: "encoding", index: 2, stage: .compute, value: .int(encoding.rawValue)),
            KernelParameterBinding(name: "samplingMode", index: 3, stage: .compute, value: .int(samplingMode.rawValue)),
            KernelParameterBinding(name: "edgeMode", index: 4, stage: .compute, value: .int(edgeMode.rawValue)),
            KernelParameterBinding(name: "usesConfidence", index: 5, stage: .compute, value: .bool(confidenceTexture != nil))
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputColorSpace: .preserveInput,
            workingColorSpace: .preserveInput,
            outputColorSpace: .preserveInput,
            inputAlphaExpectation: .preserveInput,
            outputAlpha: .preserveInput,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .dynamic,
            coordinateDependency: .transformed,
            globalDependency: .none,
            fusionPolicy: .disabled
        )
    }

    public var kernelResourceIdentity: String? {
        let confidence = confidenceTexture ?? displacementTexture
        return [
            "displacementMap",
            "flow=\(ObjectIdentifier(displacementTexture).hashValue)",
            "confidence=\(ObjectIdentifier(confidence).hashValue)",
            "hasConfidence=\(confidenceTexture == nil ? 0 : 1)"
        ].joined(separator: "|")
    }

    public func samplerAdaptation(for descriptor: ImageSamplerDescriptor) -> SamplerAdaptation {
        guard descriptor != .default else { return .notApplicable }
        let samplingMode = descriptor.compatibleSpatialSamplingMode
        let edgeMode = descriptor.compatibleSpatialEdgeMode
        guard samplingMode != nil || edgeMode != nil else { return .metadataOnly }
        var resolved = self
        if let samplingMode { resolved.samplingMode = samplingMode }
        if let edgeMode { resolved.edgeMode = edgeMode }
        if samplingMode != nil, edgeMode != nil, descriptor.mipFilter == .notMipmapped {
            return .covered(resolved)
        }
        return .partial(resolved)
    }

    public init(
        displacementTexture: MTLTexture,
        confidenceTexture: MTLTexture? = nil,
        scale: Float = 1,
        unit: DisplacementUnit = .pixels,
        encoding: DisplacementEncoding = .signed,
        samplingMode: SpatialSamplingMode = .linear,
        edgeMode: SpatialEdgeMode = .transparent
    ) {
        self.displacementTexture = displacementTexture
        self.confidenceTexture = confidenceTexture
        self.scale = scale.isFinite ? scale : 1
        self.unit = unit
        self.encoding = encoding
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
    }
}
