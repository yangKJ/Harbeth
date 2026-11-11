//
//  C7DepthLensBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/8/17.
//

import Foundation
import Metal

/// Describes a blur driven by caller-supplied relative scene depth.
///
/// The focus point uses normalized full-canvas coordinates, not physical focal length or f-stop.
public struct DepthLensBlurDescriptor: Codable, Equatable, Hashable, Sendable {
    public let focusPoint: SIMD2<Float>
    public let intensity: Float
    public let focusRange: Float
    public let transition: Float
    public let blurRadius: Float

    public init(
        focusPoint: SIMD2<Float> = SIMD2<Float>(0.5, 0.5),
        intensity: Float = 0.72,
        focusRange: Float = 0.055,
        transition: Float = 0.18,
        blurRadius: Float = 18
    ) {
        self.focusPoint = SIMD2<Float>(
            Self.clamp(focusPoint.x, to: 0...1, fallback: 0.5),
            Self.clamp(focusPoint.y, to: 0...1, fallback: 0.5)
        )
        self.intensity = Self.clamp(intensity, to: 0...1, fallback: 0.72)
        self.focusRange = Self.clamp(focusRange, to: 0.005...0.6, fallback: 0.055)
        self.transition = Self.clamp(transition, to: 0.005...0.8, fallback: 0.18)
        self.blurRadius = Self.clamp(blurRadius, to: 0...48, fallback: 18)
    }

    public static let identity = DepthLensBlurDescriptor(intensity: 0, blurRadius: 0)

    var packedValues: [Float] {
        [focusPoint.x, focusPoint.y, intensity, focusRange, transition, blurRadius]
    }

    private static func clamp(_ value: Float, to range: ClosedRange<Float>, fallback: Float) -> Float {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

/// A depth-dependent blur with an explicit auxiliary depth texture.
///
/// Deferred callers must bind an aligned depth plane at auxiliary index 0.
/// Missing depth must not silently become an ordinary blur.
public struct C7DepthLensBlur: C7FilterProtocol {
    public static let requiredDeferredAuxiliaryTextureCount = 1

    public let descriptor: DepthLensBlurDescriptor
    public let requiresDeferredDepthBinding: Bool
    private let depthTexture: MTLTexture?

    public var modifier: ModifierEnum { .compute(kernel: "C7DepthLensBlur") }
    public var computeKernelLibrarySource: KernelLibrarySource { .harbethFramework }

    public var otherInputTextures: C7InputTextures {
        depthTexture.map { [$0] } ?? []
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "depthLensBlurParameters",
                index: 0,
                stage: .compute,
                value: .floatArray(descriptor.packedValues)
            )
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern { .multiTexture }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputColorSpace: .preserveInput,
            workingColorSpace: .preserveInput,
            outputColorSpace: .preserveInput,
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            // The outer sample ring reaches twice the radius; tiles must include the entire neighborhood.
            samplingFootprint: .neighborhood(radius: Int(ceil(descriptor.blurRadius * 2))),
            coordinateDependency: .fullImage,
            globalDependency: .none,
            fusionPolicy: .disabled
        )
    }

    public var kernelResourceIdentity: String? {
        guard let depthTexture else {
            return "depthLensBlur|binding=deferred|requiredAuxiliaryInputs=1"
        }
        return "depthLensBlur|binding=direct|depth=\(ObjectIdentifier(depthTexture).hashValue)"
    }

    public init(descriptor: DepthLensBlurDescriptor, depthTexture: MTLTexture) {
        self.descriptor = descriptor
        self.depthTexture = depthTexture
        self.requiresDeferredDepthBinding = false
    }

    public static func deferred(_ descriptor: DepthLensBlurDescriptor) -> Self {
        C7DepthLensBlur(descriptor: descriptor, depthTexture: nil, requiresDeferredDepthBinding: true)
    }

    private init(descriptor: DepthLensBlurDescriptor, depthTexture: MTLTexture?, requiresDeferredDepthBinding: Bool) {
        self.descriptor = descriptor
        self.depthTexture = depthTexture
        self.requiresDeferredDepthBinding = requiresDeferredDepthBinding
    }
}
