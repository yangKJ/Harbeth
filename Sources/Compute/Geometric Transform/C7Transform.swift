//
//  C7Transform.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation
import simd

public struct C7Transform: C7FilterProtocol, SamplerAdaptableFilter {

    public var transform: CGAffineTransform
    public var anchorPoint: C7Point2D = C7Point2D.zero
    public var samplingMode: SpatialSamplingMode = .adaptive
    public var edgeMode: SpatialEdgeMode = .transparent

    public var modifier: ModifierEnum {
        return .compute(kernel: "C7AffineTransform")
    }

    public func resize(input size: C7Size) -> C7Size {
        return placement.transform(transform, size: size)
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

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "anchorX", index: 0, stage: .compute, value: .float(anchorPoint.x)),
            KernelParameterBinding(name: "anchorY", index: 1, stage: .compute, value: .float(anchorPoint.y)),
            KernelParameterBinding(name: "samplingMode", index: 2, stage: .compute, value: .float(Float(samplingMode.rawValue))),
            KernelParameterBinding(name: "edgeMode", index: 3, stage: .compute, value: .float(Float(edgeMode.rawValue))),
            KernelParameterBinding(name: "affineTransform", index: 4, stage: .compute, value: .floatArray([
                Float(transform.a), Float(transform.b),
                Float(transform.c), Float(transform.d),
                Float(transform.tx), Float(transform.ty)
            ]))
        ]
    }

    public var placement: Placement = .fit

    public init(mode: Placement = .fit, transform: CGAffineTransform, samplingMode: SpatialSamplingMode = .adaptive, edgeMode: SpatialEdgeMode = .transparent) {
        self.transform = transform
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.placement = mode
    }
}
