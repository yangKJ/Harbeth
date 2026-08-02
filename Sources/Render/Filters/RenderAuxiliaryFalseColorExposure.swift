//
//  RenderAuxiliaryFalseColorExposure.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

/// Output the main color and exposure false-color analysis diagram at the same time in a render pass.
public struct RenderAuxiliaryFalseColorExposure: RenderProtocol {

    @ZeroOneRange public var shadowThreshold: Float = 0.10
    @ZeroOneRange public var lowMidThreshold: Float = 0.35
    @ZeroOneRange public var highMidThreshold: Float = 0.70
    @ZeroOneRange public var highlightThreshold: Float = 0.92

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "dualOutputFalseColorExposureFragment")
    }

    public var renderSamplerConsumption: RenderSamplerConsumption {
        .runtimeBound
    }

    public var factors: [Float] {
        [
            shadowThreshold,
            max(lowMidThreshold, shadowThreshold),
            max(highMidThreshold, lowMidThreshold),
            max(highlightThreshold, highMidThreshold)
        ]
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

    public init(shadowThreshold: Float = 0.10, lowMidThreshold: Float = 0.35, highMidThreshold: Float = 0.70, highlightThreshold: Float = 0.92) {
        self.shadowThreshold = shadowThreshold
        self.lowMidThreshold = lowMidThreshold
        self.highMidThreshold = highMidThreshold
        self.highlightThreshold = highlightThreshold
    }

    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        nil
    }
}
