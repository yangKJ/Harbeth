//
//  RenderAuxiliaryMaskCoverage.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

/// Output the main color and mask coverage auxiliary diagram in a render pass.
public struct RenderAuxiliaryMaskCoverage: RenderProtocol {

    public let mask: MaskDescriptor

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "dualOutputMaskCoverageFragment")
    }

    public var renderSamplerConsumption: RenderSamplerConsumption {
        .runtimeBound
    }

    public var factors: [Float] {
        [
            mask.opacity,
            mask.invert ? 1 : 0,
            Float(mask.component.rawValue),
            mask.featherPolicy.amount
        ]
    }

    public var otherInputTextures: C7InputTextures {
        [mask.texture]
    }

    public var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [
                .maskCoverage(index: 1, pixelFormat: .rgba8Unorm)
            ]
        )
    }

    public init(mask: MaskDescriptor) {
        self.mask = mask
    }

    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        nil
    }
}
