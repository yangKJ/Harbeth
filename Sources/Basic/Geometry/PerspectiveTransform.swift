//
//  PerspectiveTransform.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
import QuartzCore

/// Manual perspective/upright style transform builder.
///
/// This is the Harbeth-side foundational API for the slider-driven geometry
/// controls that mainstream editors expose before they add auto/guided upright.
/// It intentionally stays deterministic and image-analysis-free.
public struct PerspectiveTransform: Equatable, Sendable {

    /// Rotation around the x-axis. Positive values pull the bottom closer.
    public var vertical: Float

    /// Rotation around the y-axis. Positive values pull the right side closer.
    public var horizontal: Float

    /// Rotation around the z-axis, used for straighten/roll.
    public var rotate: Float

    /// Uniform content scale applied before projection.
    public var scale: Float

    /// Perspective strength in radians. `0` disables perspective projection.
    public var fieldOfView: Float

    public init(vertical: Float = 0, horizontal: Float = 0, rotate: Float = 0, scale: Float = 1, fieldOfView: Float = .pi / 6) {
        self.vertical = vertical
        self.horizontal = horizontal
        self.rotate = rotate
        self.scale = scale
        self.fieldOfView = fieldOfView
    }

    public var transform3D: CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DScale(transform, CGFloat(scale), CGFloat(scale), 1)
        transform = CATransform3DRotate(transform, CGFloat(vertical), 1, 0, 0)
        transform = CATransform3DRotate(transform, CGFloat(horizontal), 0, 1, 0)
        transform = CATransform3DRotate(transform, CGFloat(rotate), 0, 0, 1)
        return transform
    }

    public var fingerprint: String {
        [
            "vertical=\(stableFloatDescription(vertical))",
            "horizontal=\(stableFloatDescription(horizontal))",
            "rotate=\(stableFloatDescription(rotate))",
            "scale=\(stableFloatDescription(scale))",
            "fov=\(stableFloatDescription(fieldOfView))"
        ].joined(separator: "|")
    }

    public func makeFilter(viewportMode: Transform3DViewportMode = .minimumEnclosing) -> RenderTransform3D {
        RenderTransform3D(perspective: self, viewportMode: viewportMode)
    }
}

private func stableFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
}

extension RenderTransform3D {

    public init(perspective: PerspectiveTransform, viewportMode: Transform3DViewportMode = .minimumEnclosing) {
        self.init(
            transform: perspective.transform3D,
            fieldOfView: perspective.fieldOfView,
            viewportMode: viewportMode
        )
    }
}
