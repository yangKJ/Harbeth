//
//  C7Rotate.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Rotate: C7FilterProtocol, SamplerAdaptableFilter {

    /// Angle to rotate, unit is degree
    @DegreeRange public var angle: Float
    public var samplingMode: SpatialSamplingMode = .adaptive
    public var edgeMode: SpatialEdgeMode = .transparent

    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Rotate")
    }

    public var factors: [Float] {
        return [Degree(value: angle).radians, Float(samplingMode.rawValue), Float(edgeMode.rawValue)]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public func resize(input size: C7Size) -> C7Size {
        return mode.rotate(angle: Degree(value: angle).radians, size: size)
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

    private var mode: Placement = .fit

    public init(mode: Placement = .fit, angle: Float = 0, samplingMode: SpatialSamplingMode = .adaptive, edgeMode: SpatialEdgeMode = .transparent) {
        self.angle = angle
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.mode = mode
    }
}
