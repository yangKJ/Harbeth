//
//  RenderTransform3D.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
import MetalKit
import QuartzCore

/// Render-based 3D transform foundation for Harbeth.
///
/// This is a better base for perspective/upright style workflows than piling
/// more special-case compute kernels onto 2D affine transforms.
public struct RenderTransform3D: RenderProtocol {

    public var transform: CATransform3D
    public var fieldOfView: Float
    public var viewportMode: Transform3DViewportMode

    public var modifier: ModifierEnum {
        .render(vertex: "projectiveVertex", fragment: "basicFragment")
    }

    public var factors: [Float] {
        [fieldOfView, Float(viewportMode.rawValue)]
    }

    public init(transform: CATransform3D = CATransform3DIdentity,
                fieldOfView: Float = 0,
                viewportMode: Transform3DViewportMode = .minimumEnclosing) {
        self.transform = transform
        self.fieldOfView = fieldOfView
        self.viewportMode = viewportMode
    }

    public func resize(input size: C7Size) -> C7Size {
        let viewport = Transform3DLayout.resolvedViewport(
            for: CGSize(width: size.width, height: size.height),
            transform: transform,
            fieldOfView: fieldOfView,
            viewportMode: viewportMode
        ).standardized
        return C7Size(
            width: max(Int(viewport.width.rounded()), 1),
            height: max(Int(viewport.height.rounded()), 1)
        )
    }

    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        nil
    }

    public func setupVertices(inputSize: C7Size) -> [Float]? {
        let viewport = Transform3DLayout.resolvedViewport(
            for: CGSize(width: inputSize.width, height: inputSize.height),
            transform: transform,
            fieldOfView: fieldOfView,
            viewportMode: viewportMode
        )
        return Transform3DLayout.projectedVertices(
            for: CGSize(width: inputSize.width, height: inputSize.height),
            transform: transform,
            fieldOfView: fieldOfView,
            viewport: viewport
        )
    }

    public var renderVertexStride: Int { 5 }
}
