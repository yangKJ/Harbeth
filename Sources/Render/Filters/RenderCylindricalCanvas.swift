//
//  RenderCylindricalCanvas.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import Foundation
import MetalKit
import simd

/// 将输入纹理按柱面逆映射投影到显式像素画布，并独立输出几何 coverage。
///
/// 该 primitive 只描述单帧柱面采样合同，不包含拼接模式选择、焦距搜索或全局配准。
public struct RenderCylindricalCanvas: RenderProtocol {

    public var canvasToProjected: simd_float3x3
    public var focalLength: Float
    public var principalPoint: SIMD2<Float>
    public var outputSize: C7Size
    public var edgeFeatherFraction: Float

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "cylindricalCanvasFragment")
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

    public init(canvasToProjected: simd_float3x3,
                focalLength: Float,
                principalPoint: SIMD2<Float>,
                outputSize: C7Size,
                edgeFeatherFraction: Float = 0) {
        self.canvasToProjected = canvasToProjected
        self.focalLength = max(focalLength, 1)
        self.principalPoint = principalPoint
        self.outputSize = outputSize
        self.edgeFeatherFraction = min(max(edgeFeatherFraction, 0), 0.5)
    }

    public func resize(input size: C7Size) -> C7Size {
        outputSize
    }

    public func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer? {
        var uniforms = RenderCylindricalCanvasUniforms(
            canvasToProjected: canvasToProjected,
            principalPoint: principalPoint,
            sourceSize: SIMD2(Float(inputSize.width), Float(inputSize.height)),
            outputSize: SIMD2(Float(outputSize.width), Float(outputSize.height)),
            focalLength: focalLength,
            edgeFeatherFraction: edgeFeatherFraction,
            padding: SIMD2<Float>(repeating: 0)
        )
        return device.makeBuffer(bytes: &uniforms, length: MemoryLayout<RenderCylindricalCanvasUniforms>.stride, options: [])
    }
}

struct RenderCylindricalCanvasUniforms {
    var canvasToProjected: simd_float3x3
    var principalPoint: SIMD2<Float>
    var sourceSize: SIMD2<Float>
    var outputSize: SIMD2<Float>
    var focalLength: Float
    var edgeFeatherFraction: Float
    var padding: SIMD2<Float>
}
