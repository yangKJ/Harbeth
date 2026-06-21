//
//  RenderAuxiliaryLuminance.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

/// 在一次 render pass 内同时输出主色结果和辅助亮度图。
public struct RenderAuxiliaryLuminance: RenderProtocol {

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "dualOutputLuminanceFragment")
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
