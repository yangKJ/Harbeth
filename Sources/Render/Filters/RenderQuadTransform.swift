//
//  RenderQuadTransform.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
import MetalKit
import simd

/// Four-corner perspective transform foundation.
///
/// This is the low-level primitive behind live perspective, corner pin,
/// document correction, and future guided upright style workflows.
public struct RenderQuadTransform: RenderProtocol, SamplerAdaptableFilter {

    public struct Quad: Equatable, Codable, Sendable {
        public static let identity = Quad(
            topLeft: .init(x: 0, y: 0),
            topRight: .init(x: 1, y: 0),
            bottomLeft: .init(x: 0, y: 1),
            bottomRight: .init(x: 1, y: 1)
        )

        public var topLeft: FreePoint2D
        public var topRight: FreePoint2D
        public var bottomLeft: FreePoint2D
        public var bottomRight: FreePoint2D

        public init(topLeft: FreePoint2D, topRight: FreePoint2D, bottomLeft: FreePoint2D, bottomRight: FreePoint2D) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomLeft = bottomLeft
            self.bottomRight = bottomRight
        }
    }

    public var quad: Quad
    public var viewportMode: Transform3DViewportMode
    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode

    public var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "quadTransformFragment")
    }

    public init(quad: Quad = .identity,
                viewportMode: Transform3DViewportMode = .minimumEnclosing,
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent) {
        self.quad = quad
        self.viewportMode = viewportMode
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
    }

    public func resize(input size: C7Size) -> C7Size {
        let viewport = RenderQuadTransformLayout.resolvedViewport(
            for: CGSize(width: size.width, height: size.height),
            quad: quad,
            viewportMode: viewportMode
        ).standardized

        return C7Size(
            width: max(Int(viewport.width.rounded()), 1),
            height: max(Int(viewport.height.rounded()), 1)
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
        return .covered(resolved)
    }

    public func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer? {
        let size = CGSize(width: inputSize.width, height: inputSize.height)
        let viewport = RenderQuadTransformLayout.resolvedViewport(
            for: size,
            quad: quad,
            viewportMode: viewportMode
        ).standardized

        var uniforms = RenderQuadTransformFragmentUniforms(
            inverseHomography: RenderQuadTransformLayout.inverseHomography(for: size, quad: quad),
            viewportOrigin: SIMD2(Float(viewport.minX), Float(viewport.minY)),
            viewportSize: SIMD2(Float(viewport.width), Float(viewport.height)),
            samplingMode: UInt32(samplingMode.rawValue),
            edgeMode: UInt32(edgeMode.rawValue),
            padding: SIMD2<UInt32>(0, 0)
        )

        return device.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<RenderQuadTransformFragmentUniforms>.stride,
            options: []
        )
    }
}

struct RenderQuadTransformFragmentUniforms {
    var inverseHomography: simd_float3x3
    var viewportOrigin: SIMD2<Float>
    var viewportSize: SIMD2<Float>
    var samplingMode: UInt32
    var edgeMode: UInt32
    var padding: SIMD2<UInt32>
}

private struct RenderQuadTransformLayout {

    static func defaultViewport(for inputSize: CGSize) -> CGRect {
        CGRect(x: -0.5 * inputSize.width, y: -0.5 * inputSize.height, width: inputSize.width, height: inputSize.height)
    }

    static func resolvedViewport(for inputSize: CGSize, quad: RenderQuadTransform.Quad, viewportMode: Transform3DViewportMode) -> CGRect {
        switch viewportMode {
        case .original:
            return defaultViewport(for: inputSize)
        case .minimumEnclosing:
            let points = destinationPoints(for: inputSize, quad: quad)
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
                return defaultViewport(for: inputSize)
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }

    static func inverseHomography(for inputSize: CGSize, quad: RenderQuadTransform.Quad) -> simd_float3x3 {
        let sourceViewport = defaultViewport(for: inputSize)
        let source = [
            CGPoint(x: sourceViewport.minX, y: sourceViewport.minY),
            CGPoint(x: sourceViewport.maxX, y: sourceViewport.minY),
            CGPoint(x: sourceViewport.minX, y: sourceViewport.maxY),
            CGPoint(x: sourceViewport.maxX, y: sourceViewport.maxY),
        ]
        let destination = destinationPoints(for: inputSize, quad: quad)
        return Homography.mapping(from: destination, to: source)
    }

    private static func destinationPoints(for inputSize: CGSize, quad: RenderQuadTransform.Quad) -> [CGPoint] {
        let viewport = defaultViewport(for: inputSize)

        func point(_ value: FreePoint2D) -> CGPoint {
            CGPoint(
                x: viewport.minX + CGFloat(value.x) * inputSize.width,
                y: viewport.minY + CGFloat(value.y) * inputSize.height
            )
        }

        return [point(quad.topLeft), point(quad.topRight), point(quad.bottomLeft), point(quad.bottomRight)]
    }
}
