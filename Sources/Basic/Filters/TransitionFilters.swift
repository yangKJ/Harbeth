//
//  TransitionFilters.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public protocol TransitionKernel: C7FilterProtocol {
    var toTexture: MTLTexture { get set }
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

// 内置转场共享画布与关联颜色合同，自定义转场继续自行声明。
protocol BuiltinTransitionKernel: TransitionKernel {}
extension BuiltinTransitionKernel {
    var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .premultiplied,
              samplingFootprint: .dynamic, coordinateDependency: .transformed,
              globalDependency: .imageDimensions, fusionPolicy: .disabled)
    }
    var kernelOutputContract: RenderOutputContract { .premultipliedColorOutput }
}

struct DissolveTransition: BuiltinTransitionKernel {
    var toTexture: MTLTexture
    var progress: Float
    var auxiliaryTextures: [MTLTexture] { [] }

    init(toTexture: MTLTexture, progress: Float) {
        self.toTexture = toTexture
        self.progress = sanitizedTransitionFloat(progress, fallback: 0, range: 0...1)
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerDissolveTransition") }
    var factors: [Float] { [sanitizedTransitionFloat(progress, fallback: 0, range: 0...1)] }
}

struct DirectionalWipeTransition: BuiltinTransitionKernel {
    var toTexture: MTLTexture
    var progress: Float
    var angleDegrees: Float
    var softness: Float
    var auxiliaryTextures: [MTLTexture] { [] }

    init(toTexture: MTLTexture, progress: Float, angleDegrees: Float = 0, softness: Float = 0.02) {
        self.toTexture = toTexture
        self.progress = sanitizedTransitionFloat(progress, fallback: 0, range: 0...1)
        self.angleDegrees = angleDegrees.isFinite ? angleDegrees : 0
        self.softness = sanitizedTransitionFloat(softness, fallback: 0.02, range: 0.0001...(Float.greatestFiniteMagnitude / 4))
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerDirectionalWipeTransition") }
    var factors: [Float] {
        let angle = angleDegrees.isFinite ? angleDegrees.truncatingRemainder(dividingBy: 360) : 0
        return [sanitizedTransitionFloat(progress, fallback: 0, range: 0...1), Degree(value: angle).radians,
                sanitizedTransitionFloat(softness, fallback: 0.02, range: 0.0001...(Float.greatestFiniteMagnitude / 4))]
    }
}

struct LumaWipeTransition: BuiltinTransitionKernel {
    var toTexture: MTLTexture
    let lumaTexture: MTLTexture
    var progress: Float
    var softness: Float
    var auxiliaryTextures: [MTLTexture] { [lumaTexture] }

    init(toTexture: MTLTexture, lumaTexture: MTLTexture, progress: Float, softness: Float = 0.1) {
        self.toTexture = toTexture
        self.lumaTexture = lumaTexture
        self.progress = sanitizedTransitionFloat(progress, fallback: 0, range: 0...1)
        self.softness = sanitizedTransitionFloat(softness, fallback: 0.1, range: 0.0001...(Float.greatestFiniteMagnitude / 4))
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerLumaWipeTransition") }
    var factors: [Float] { [sanitizedTransitionFloat(progress, fallback: 0, range: 0...1), sanitizedTransitionFloat(softness, fallback: 0.1, range: 0.0001...(Float.greatestFiniteMagnitude / 4))] }
}

struct DisplacementTransition: BuiltinTransitionKernel {
    var toTexture: MTLTexture
    let displacementTexture: MTLTexture
    var progress: Float
    var scale: Float
    var auxiliaryTextures: [MTLTexture] { [displacementTexture] }

    init(toTexture: MTLTexture, displacementTexture: MTLTexture, progress: Float, scale: Float = 0.05) {
        self.toTexture = toTexture
        self.displacementTexture = displacementTexture
        self.progress = sanitizedTransitionFloat(progress, fallback: 0, range: 0...1)
        self.scale = (scale.isFinite ? scale : 0.05)
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerDisplacementTransition") }
    var factors: [Float] { [sanitizedTransitionFloat(progress, fallback: 0, range: 0...1), (scale.isFinite ? scale : 0.05)] }
}

struct PageCurlTransition: BuiltinTransitionKernel {
    var toTexture: MTLTexture
    let backsideTexture: MTLTexture?
    var progress: Float
    var angleDegrees: Float
    var radius: Float
    var shadowStrength: Float
    var shadowRadius: Float
    var auxiliaryTextures: [MTLTexture] { backsideTexture.map { [$0] } ?? [] }

    init(toTexture: MTLTexture,
         backsideTexture: MTLTexture? = nil,
         progress: Float,
         angleDegrees: Float = 0,
         radius: Float = 0.22,
         shadowStrength: Float = 0.7,
         shadowRadius: Float = 0.06) {
        self.toTexture = toTexture
        self.backsideTexture = backsideTexture
        self.progress = Self.sanitized(progress, fallback: 0, range: 0...1)
        self.angleDegrees = angleDegrees.isFinite ? angleDegrees : 0
        self.radius = Self.sanitized(radius, fallback: 0.22, range: 0.001...0.5)
        self.shadowStrength = Self.sanitized(shadowStrength, fallback: 0.7, range: 0...1)
        self.shadowRadius = Self.sanitized(shadowRadius, fallback: 0.06, range: 0.001...0.5)
    }

    var modifier: ModifierEnum {
        .compute(kernel: backsideTexture == nil ? "InnerPageCurlTransition" : "InnerPageCurlBacksideTransition")
    }

    var factors: [Float] {
        let angle = angleDegrees.isFinite ? angleDegrees.truncatingRemainder(dividingBy: 360) : 0
        let radians = Degree(value: angle).radians
        return [Self.sanitized(progress, fallback: 0, range: 0...1), cos(radians), sin(radians),
                Self.sanitized(radius, fallback: 0.22, range: 0.001...0.5),
                Self.sanitized(shadowStrength, fallback: 0.7, range: 0...1),
                Self.sanitized(shadowRadius, fallback: 0.06, range: 0.001...0.5)]
    }

    var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .dynamic,
            coordinateDependency: .transformed,
            globalDependency: .imageDimensions,
            fusionPolicy: .disabled
        )
    }

    private static func sanitized(_ value: Float, fallback: Float, range: ClosedRange<Float>) -> Float {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
