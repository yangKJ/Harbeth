//
//  RenderProjectiveCanvas.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import Foundation
import MetalKit
import simd

/// 将输入纹理按任意逆 Homography 投影到显式像素画布，并独立输出几何 coverage。
///
/// 该 primitive 只描述单帧几何与采样合同，不包含全景配准、接缝、曝光或裁边策略。
public struct RenderProjectiveCanvas: RenderProtocol {

    public var canvasToSource: simd_float3x3
    public var canvasOrigin: SIMD2<Float>
    public var outputSize: C7Size
    public var edgeFeatherFraction: Float

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "projectiveCanvasFragment")
    }

    public var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .preserveInput,
            pixelFormat: .rgba16Float,
            additionalAttachments: [
                .coverage(index: 1, pixelFormat: .r16Float)
            ]
        )
    }

    public init(canvasToSource: simd_float3x3,
                canvasOrigin: SIMD2<Float> = .zero,
                outputSize: C7Size,
                edgeFeatherFraction: Float = 0) {
        self.canvasToSource = canvasToSource
        self.canvasOrigin = canvasOrigin
        self.outputSize = outputSize
        self.edgeFeatherFraction = min(max(edgeFeatherFraction, 0), 0.5)
    }

    public func resize(input size: C7Size) -> C7Size {
        outputSize
    }

    public func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer? {
        var uniforms = RenderProjectiveCanvasUniforms(
            canvasToSource: canvasToSource,
            canvasOrigin: canvasOrigin,
            sourceSize: SIMD2(Float(inputSize.width), Float(inputSize.height)),
            outputSize: SIMD2(Float(outputSize.width), Float(outputSize.height)),
            edgeFeatherFraction: edgeFeatherFraction,
            padding: SIMD3<Float>(repeating: 0)
        )
        return device.makeBuffer(bytes: &uniforms, length: MemoryLayout<RenderProjectiveCanvasUniforms>.stride, options: [])
    }
}

struct RenderProjectiveCanvasUniforms {
    var canvasToSource: simd_float3x3
    var canvasOrigin: SIMD2<Float>
    var sourceSize: SIMD2<Float>
    var outputSize: SIMD2<Float>
    var edgeFeatherFraction: Float
    var padding: SIMD3<Float>
}
