//
//  RenderAuxiliaryLuminance.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

/// Output the main color result and auxiliary brightness map at the same time in a render pass.
public struct RenderAuxiliaryLuminance: RenderProtocol {

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "dualOutputLuminanceFragment")
    }

    public var renderSamplerConsumption: RenderSamplerConsumption {
        .runtimeBound
    }

    public var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [
                .luminance(index: 1, pixelFormat: .rgba8Unorm)
            ]
        )
    }

    public init() { }

    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        nil
    }
}
