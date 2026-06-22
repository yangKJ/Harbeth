//
//  TransitionRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum TransitionKernelDescriptor {
    case dissolve
    case directionalWipe(angleDegrees: Float = 0, softness: Float = 0.02)
    case lumaWipe(lumaSource: ImageSource, softness: Float = 0.1)
    case displacement(displacementSource: ImageSource, scale: Float = 0.05)

    var fingerprint: String {
        switch self {
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
        }
    }

    func makeFilter(toTexture: MTLTexture, progress: Float) throws -> C7FilterProtocol {
        switch self {
        case .dissolve:
            return C7DissolveTransition(toTexture: toTexture, progress: progress)
        case .directionalWipe(let angleDegrees, let softness):
            return C7DirectionalWipeTransition(
                toTexture: toTexture,
                progress: progress,
                angleDegrees: angleDegrees,
                softness: softness
            )
        case .lumaWipe(let lumaSource, let softness):
            return C7LumaWipeTransition(
                toTexture: toTexture,
                lumaTexture: try lumaSource.makeTexture(),
                progress: progress,
                softness: softness
            )
        case .displacement(let displacementSource, let scale):
            return C7DisplacementTransition(
                toTexture: toTexture,
                displacementTexture: try displacementSource.makeTexture(),
                progress: progress,
                scale: scale
            )
        }
    }
}

private func stableTransitionFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
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
        self.progress = min(max(progress, 0), 1)
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
