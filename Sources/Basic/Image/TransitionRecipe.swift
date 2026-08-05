//
//  TransitionRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum TransitionKernelDescriptor {
    case custom(TransitionKernel)
    case dissolve
    case directionalWipe(angleDegrees: Float = 0, softness: Float = 0.02)
    case lumaWipe(lumaSource: ImageSource, softness: Float = 0.1)
    case displacement(displacementSource: ImageSource, scale: Float = 0.05)
    case pageCurl(
        angleDegrees: Float = 0,
        radius: Float = 0.22,
        shadowStrength: Float = 0.7,
        shadowRadius: Float = 0.06,
        backsideSource: ImageSource? = nil
    )

    var fingerprint: String {
        switch self {
        case .custom(let filter):
            return "custom|\(filter.identifier)"
        case .dissolve:
            return "dissolve"
        case .directionalWipe(let angleDegrees, let softness):
            return [
                "directionalWipe",
                "angle=\(stableTransitionFloatDescription(angleDegrees))",
                "softness=\(stableTransitionFloatDescription(softness))"
            ].joined(separator: "|")
        case .lumaWipe(let lumaSource, let softness):
            return [
                "lumaWipe",
                lumaSource.resolutionFingerprint,
                "softness=\(stableTransitionFloatDescription(softness))"
            ].joined(separator: "|")
        case .displacement(let displacementSource, let scale):
            return [
                "displacement",
                displacementSource.resolutionFingerprint,
                "scale=\(stableTransitionFloatDescription(scale))"
            ].joined(separator: "|")
        case .pageCurl(let angleDegrees, let radius, let shadowStrength, let shadowRadius, let backsideSource):
            let effectiveAngle = angleDegrees.isFinite ? angleDegrees : 0
            let effectiveRadius = sanitizedTransitionFloat(radius, fallback: 0.22, range: 0.001...0.5)
            let effectiveShadowStrength = sanitizedTransitionFloat(shadowStrength, fallback: 0.7, range: 0...1)
            let effectiveShadowRadius = sanitizedTransitionFloat(shadowRadius, fallback: 0.06, range: 0.001...0.5)
            return [
                "pageCurl",
                "angle=\(stableTransitionFloatDescription(effectiveAngle))",
                "radius=\(stableTransitionFloatDescription(effectiveRadius))",
                "shadowStrength=\(stableTransitionFloatDescription(effectiveShadowStrength))",
                "shadowRadius=\(stableTransitionFloatDescription(effectiveShadowRadius))",
                backsideSource.map { "backside={\($0.resolutionFingerprint)}" } ?? "backside=fallback"
            ].joined(separator: "|")
        }
    }

    func makeFilter(toTexture: MTLTexture, progress: Float) throws -> C7FilterProtocol {
        switch self {
        case .custom(var filter):
            // Refresh per-frame source texture and progress; preserve user-provided auxiliary textures.
            filter.toTexture = toTexture
            filter.progress = progress
            return filter
        case .dissolve:
            return DissolveTransition(toTexture: toTexture, progress: progress)
        case .directionalWipe(let angleDegrees, let softness):
            return DirectionalWipeTransition(
                toTexture: toTexture,
                progress: progress,
                angleDegrees: angleDegrees,
                softness: softness
            )
        case .lumaWipe(let lumaSource, let softness):
            return LumaWipeTransition(
                toTexture: toTexture,
                lumaTexture: try lumaSource.makeTexture(),
                progress: progress,
                softness: softness
            )
        case .displacement(let displacementSource, let scale):
            return DisplacementTransition(
                toTexture: toTexture,
                displacementTexture: try displacementSource.makeTexture(),
                progress: progress,
                scale: scale
            )
        case .pageCurl(let angleDegrees, let radius, let shadowStrength, let shadowRadius, let backsideSource):
            return PageCurlTransition(
                toTexture: toTexture,
                backsideTexture: try backsideSource?.makeTexture(),
                progress: progress,
                angleDegrees: angleDegrees,
                radius: radius,
                shadowStrength: shadowStrength,
                shadowRadius: shadowRadius
            )
        }
    }
}

private func stableTransitionFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
}

private func sanitizedTransitionFloat(_ value: Float, fallback: Float, range: ClosedRange<Float>) -> Float {
    guard value.isFinite else { return fallback }
    return min(max(value, range.lowerBound), range.upperBound)
}

public struct TransitionRecipe {
    public var from: ImageSource
    public var to: ImageSource
    public var kernel: TransitionKernelDescriptor
    public var progress: Float
    public var profile: RenderProfile
    public var derivative: ImageDerivativeSpec

    public init(from: ImageSource,
                to: ImageSource,
                kernel: TransitionKernelDescriptor,
                progress: Float,
                profile: RenderProfile = .stablePreview,
                derivative: ImageDerivativeSpec? = nil) {
        self.from = from
        self.to = to
        self.kernel = kernel
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        self.profile = profile
        self.derivative = derivative ?? profile.defaultDerivativeSpec
    }

    public func makeNode() -> ImageNode {
        .transition(self)
    }

    func makeFilter() throws -> C7FilterProtocol {
        try kernel.makeFilter(
            toTexture: to.makeTexture(),
            progress: progress
        )
    }
}

extension ImageNode {
    public static func transition(_ recipe: TransitionRecipe) -> ImageNode {
        ImageNode(storage: .transition(recipe))
    }

    public static func transition(from: ImageSource,
                                  to: ImageSource,
                                  kernel: TransitionKernelDescriptor,
                                  progress: Float,
                                  profile: RenderProfile = .stablePreview,
                                  derivative: ImageDerivativeSpec? = nil) -> ImageNode {
        transition(
            TransitionRecipe(
                from: from,
                to: to,
                kernel: kernel,
                progress: progress,
                profile: profile,
                derivative: derivative
            )
        )
    }
}
