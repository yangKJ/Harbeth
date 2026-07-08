//
//  C7LensDistortionCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 基础镜头几何畸变校正。
///
/// `distortion` 用于一次径向畸变，`cubicDistortion` 用于更强的外圈修正。
/// 正负号的实际视觉取决于原图是桶形还是枕形畸变，因此这里保持底座中立，
/// 由上层产品用预设或 profile 决定默认值。
public struct C7LensDistortionCorrection: C7FilterProtocol, SamplerAdaptableFilter {

    public var center: C7Point2D = .center
    public var distortion: Float
    public var cubicDistortion: Float
    public var scale: Float
    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode

    public var modifier: ModifierEnum {
        .compute(kernel: "C7LensDistortionCorrection")
    }

    public var factors: [Float] {
        [
            center.x,
            center.y,
            distortion,
            cubicDistortion,
            scale,
            Float(samplingMode.rawValue),
            Float(edgeMode.rawValue)
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
        return .covered(resolved)
    }

    public init(center: C7Point2D = .center,
                distortion: Float = 0,
                cubicDistortion: Float = 0,
                scale: Float = 1,
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent) {
        self.center = center
        self.distortion = distortion
        self.cubicDistortion = cubicDistortion
        self.scale = scale
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
    }
}
