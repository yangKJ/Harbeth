//
//  RenderQuadRectifyTransform.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
import MetalKit
import simd

/// Rectifies an arbitrary source quadrilateral into a front-facing rectangle.
///
/// This is the geometric primitive behind document correction, guided upright
/// region solving, and perspective crop workflows.
public struct RenderQuadRectifyTransform: RenderProtocol, SamplerAdaptableFilter {

    public var sourceQuad: RenderQuadTransform.Quad
    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode
    public var outputScale: Float

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "quadTransformFragment")
    }

    public var renderSamplerConsumption: RenderSamplerConsumption {
        .shaderDefined
    }

    public init(sourceQuad: RenderQuadTransform.Quad,
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent,
                outputScale: Float = 1) {
        self.sourceQuad = sourceQuad
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.outputScale = outputScale
    }

    public func resize(input size: C7Size) -> C7Size {
        let inputSize = CGSize(width: size.width, height: size.height)
        let resolvedSize = estimatedOutputSize(inputSize: inputSize)

        return C7Size(
            width: max(Int((resolvedSize.width * CGFloat(outputScale)).rounded()), 1),
            height: max(Int((resolvedSize.height * CGFloat(outputScale)).rounded()), 1)
        )
    }

    public func setupVertices(inputSize: C7Size) -> [Float]? {
        [
            -1.0, -1.0, 0.0, 1.0,
             1.0, -1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0,
             1.0,  1.0, 1.0, 0.0,
        ]
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

    public func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer? {
        let input = CGSize(width: inputSize.width, height: inputSize.height)
        let output = estimatedOutputSize(inputSize: input)
        let viewport = CGRect(
            x: -0.5 * output.width,
            y: -0.5 * output.height,
            width: output.width,
            height: output.height
        )

        let rectangle = [
            CGPoint(x: viewport.minX, y: viewport.minY),
            CGPoint(x: viewport.maxX, y: viewport.minY),
            CGPoint(x: viewport.minX, y: viewport.maxY),
            CGPoint(x: viewport.maxX, y: viewport.maxY)
        ]

        let source = sourcePoints(for: input)
        var uniforms = RenderQuadTransformFragmentUniforms(
            inverseHomography: Homography.mapping(from: rectangle, to: source),
            viewportOrigin: SIMD2(Float(viewport.minX), Float(viewport.minY)),
            viewportSize: SIMD2(Float(viewport.width), Float(viewport.height)),
            samplingMode: UInt32(samplingMode.rawValue),
            edgeMode: UInt32(edgeMode.rawValue),
            padding: SIMD2<UInt32>(0, 0)
        )

        return device.makeBuffer(bytes: &uniforms, length: MemoryLayout<RenderQuadTransformFragmentUniforms>.stride, options: [])
    }

    private func estimatedOutputSize(inputSize: CGSize) -> CGSize {
        let points = sourcePoints(for: inputSize)
        let topWidth = points[0].c7.distance(to: points[1])
        let bottomWidth = points[2].c7.distance(to: points[3])
        let leftHeight = points[0].c7.distance(to: points[2])
        let rightHeight = points[1].c7.distance(to: points[3])

        return CGSize(
            width: max((topWidth + bottomWidth) * 0.5, 1),
            height: max((leftHeight + rightHeight) * 0.5, 1)
        )
    }

    private func sourcePoints(for inputSize: CGSize) -> [CGPoint] {
        let viewport = CGRect(
            x: -0.5 * inputSize.width,
            y: -0.5 * inputSize.height,
            width: inputSize.width,
            height: inputSize.height
        )

        func point(_ value: FreePoint2D) -> CGPoint {
            CGPoint(
                x: viewport.minX + CGFloat(value.x) * inputSize.width,
                y: viewport.minY + CGFloat(value.y) * inputSize.height
            )
        }

        return [
            point(sourceQuad.topLeft),
            point(sourceQuad.topRight),
            point(sourceQuad.bottomLeft),
            point(sourceQuad.bottomRight)
        ]
    }
}
