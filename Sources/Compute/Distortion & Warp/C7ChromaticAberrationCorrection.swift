//
//  C7ChromaticAberrationCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 基础色差校正。
///
/// 通过沿图像中心到边缘的径向方向对各颜色通道做重对齐，
/// 用于修正镜头在高反差边缘产生的红/青、蓝/黄类色边。
public struct C7ChromaticAberrationCorrection: C7FilterProtocol, SamplerAdaptableFilter {

    public var center: C7Point2D = .center

    /// Red/cyan channel realignment strength.
    public var redCyanShift: Float

    /// Blue/yellow channel realignment strength.
    public var blueYellowShift: Float

    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode

    public var modifier: ModifierEnum {
        .compute(kernel: "C7ChromaticAberrationCorrection")
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "center", index: 0, stage: .compute, value: .float2(center.toSIMD2())),
            KernelParameterBinding(name: "channelShifts", index: 1, stage: .compute, value: .float2(SIMD2<Float>(redCyanShift, blueYellowShift))),
            KernelParameterBinding(name: "samplingMode", index: 2, stage: .compute, value: .int(samplingMode.rawValue)),
            KernelParameterBinding(name: "edgeMode", index: 3, stage: .compute, value: .int(edgeMode.rawValue))
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public func samplerAdaptation(for descriptor: ImageSamplerDescriptor) -> SamplerAdaptation {
        guard descriptor != .default else {
            return .notApplicable
        }
        let samplingMode = descriptor.compatibleSpatialSamplingMode
        let edgeMode = descriptor.compatibleSpatialEdgeMode
        guard samplingMode != nil || edgeMode != nil else {
            return .metadataOnly
        }
        var resolved = self
        if let samplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode {
            resolved.edgeMode = edgeMode
        }
        if samplingMode != nil, edgeMode != nil, descriptor.mipFilter == .notMipmapped {
            return .covered(resolved)
        }
        return .partial(resolved)
    }

    public init(center: C7Point2D = .center,
                redCyanShift: Float = 0,
                blueYellowShift: Float = 0,
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent) {
        self.center = center
        self.redCyanShift = redCyanShift
        self.blueYellowShift = blueYellowShift
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
    }
}
