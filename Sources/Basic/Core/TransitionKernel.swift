//
//  TransitionKernel.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal
import CoreGraphics

public protocol TransitionKernel: C7FilterProtocol {
    var toTexture: MTLTexture { get }
    var progress: Float { get set }
    var auxiliaryTextures: [MTLTexture] { get }
}

public extension TransitionKernel {
    var otherInputTextures: C7InputTextures {
        [toTexture] + auxiliaryTextures
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

public struct C7DissolveTransition: TransitionKernel {
    public let toTexture: MTLTexture
    public var progress: Float
    public var auxiliaryTextures: [MTLTexture] { [] }

    public init(toTexture: MTLTexture, progress: Float) {
        self.toTexture = toTexture
        self.progress = min(max(progress, 0), 1)
    }

    public var modifier: ModifierEnum { .compute(kernel: "C7DissolveTransition") }
    public var factors: [Float] { [progress] }
}

public struct C7DirectionalWipeTransition: TransitionKernel {
    public let toTexture: MTLTexture
    public var progress: Float
    public var angleDegrees: Float
    public var softness: Float
    public var auxiliaryTextures: [MTLTexture] { [] }

    public init(toTexture: MTLTexture,
                progress: Float,
                angleDegrees: Float = 0,
                softness: Float = 0.02) {
        self.toTexture = toTexture
        self.progress = min(max(progress, 0), 1)
        self.angleDegrees = angleDegrees
        self.softness = max(softness, 0.0001)
    }

    public var modifier: ModifierEnum { .compute(kernel: "C7DirectionalWipeTransition") }
    public var factors: [Float] { [progress, Degree(value: angleDegrees).radians, softness] }
}

public struct C7LumaWipeTransition: TransitionKernel {
    public let toTexture: MTLTexture
    public let lumaTexture: MTLTexture
    public var progress: Float
    public var softness: Float
    public var auxiliaryTextures: [MTLTexture] { [lumaTexture] }

    public init(toTexture: MTLTexture,
                lumaTexture: MTLTexture,
                progress: Float,
                softness: Float = 0.1) {
        self.toTexture = toTexture
        self.lumaTexture = lumaTexture
        self.progress = min(max(progress, 0), 1)
        self.softness = max(softness, 0.0001)
    }

    public var modifier: ModifierEnum { .compute(kernel: "C7LumaWipeTransition") }
    public var factors: [Float] { [progress, softness] }
}

public struct C7DisplacementTransition: TransitionKernel {
    public let toTexture: MTLTexture
    public let displacementTexture: MTLTexture
    public var progress: Float
    public var scale: Float
    public var auxiliaryTextures: [MTLTexture] { [displacementTexture] }

    public init(toTexture: MTLTexture,
                displacementTexture: MTLTexture,
                progress: Float,
                scale: Float = 0.05) {
        self.toTexture = toTexture
        self.displacementTexture = displacementTexture
        self.progress = min(max(progress, 0), 1)
        self.scale = scale
    }

    public var modifier: ModifierEnum { .compute(kernel: "C7DisplacementTransition") }
    public var factors: [Float] { [progress, scale] }
}

public enum TransitionKernelDescriptor {
    case dissolve
    case directionalWipe(angleDegrees: Float = 0, softness: Float = 0.02)
    case lumaWipe(lumaSource: HarbethSource, softness: Float = 0.1)
    case displacement(displacementSource: HarbethSource, scale: Float = 0.05)

    public var fingerprint: String {
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
    public var from: HarbethSource
    public var to: HarbethSource
    public var kernel: TransitionKernelDescriptor
    public var progress: Float
    public var profile: RenderProfile
    public var derivative: ImageDerivativeSpec

    public init(from: HarbethSource,
                to: HarbethSource,
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

    func makeFilter() throws -> C7FilterProtocol {
        try kernel.makeFilter(
            toTexture: to.makeTexture(),
            progress: progress
        )
    }
}
