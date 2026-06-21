//
//  RenderAuxiliaryHighlightClipping.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

/// 在一次 render pass 内同时输出主颜色和高光裁切分析图。
public struct RenderAuxiliaryHighlightClipping: RenderProtocol {

    @ZeroOneRange public var threshold: Float = 0.92
    @ZeroOneRange public var softness: Float = 0.03

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "dualOutputHighlightClippingFragment")
    }

    public var factors: [Float] {
        [threshold, softness]
    }

    public var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [
                .analysis(index: 1, pixelFormat: .rgba8Unorm)
            ]
        )
    }

    public init(threshold: Float = 0.92, softness: Float = 0.03) {
        self.threshold = threshold
        self.softness = softness
    }

    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        nil
    }
}
