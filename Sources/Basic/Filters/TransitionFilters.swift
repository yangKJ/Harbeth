//
//  TransitionFilters.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

protocol TransitionKernel: C7FilterProtocol {
    var toTexture: MTLTexture { get }
    var progress: Float { get set }
    var auxiliaryTextures: [MTLTexture] { get }
}

extension TransitionKernel {
    var otherInputTextures: C7InputTextures {
        [toTexture] + auxiliaryTextures
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

struct DissolveTransition: TransitionKernel {
    let toTexture: MTLTexture
    var progress: Float
    var auxiliaryTextures: [MTLTexture] { [] }

    init(toTexture: MTLTexture, progress: Float) {
        self.toTexture = toTexture
        self.progress = min(max(progress, 0), 1)
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerDissolveTransition") }
    var factors: [Float] { [progress] }
}

struct DirectionalWipeTransition: TransitionKernel {
    let toTexture: MTLTexture
    var progress: Float
    var angleDegrees: Float
    var softness: Float
    var auxiliaryTextures: [MTLTexture] { [] }

    init(toTexture: MTLTexture, progress: Float, angleDegrees: Float = 0, softness: Float = 0.02) {
        self.toTexture = toTexture
        self.progress = min(max(progress, 0), 1)
        self.angleDegrees = angleDegrees
        self.softness = max(softness, 0.0001)
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerDirectionalWipeTransition") }
    var factors: [Float] { [progress, Degree(value: angleDegrees).radians, softness] }
}

struct LumaWipeTransition: TransitionKernel {
    let toTexture: MTLTexture
    let lumaTexture: MTLTexture
    var progress: Float
    var softness: Float
    var auxiliaryTextures: [MTLTexture] { [lumaTexture] }

    init(toTexture: MTLTexture, lumaTexture: MTLTexture, progress: Float, softness: Float = 0.1) {
        self.toTexture = toTexture
        self.lumaTexture = lumaTexture
        self.progress = min(max(progress, 0), 1)
        self.softness = max(softness, 0.0001)
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerLumaWipeTransition") }
    var factors: [Float] { [progress, softness] }
}

struct DisplacementTransition: TransitionKernel {
    let toTexture: MTLTexture
    let displacementTexture: MTLTexture
    var progress: Float
    var scale: Float
    var auxiliaryTextures: [MTLTexture] { [displacementTexture] }

    init(toTexture: MTLTexture, displacementTexture: MTLTexture, progress: Float, scale: Float = 0.05) {
        self.toTexture = toTexture
        self.displacementTexture = displacementTexture
        self.progress = min(max(progress, 0), 1)
        self.scale = scale
    }

    var modifier: ModifierEnum { .compute(kernel: "InnerDisplacementTransition") }
    var factors: [Float] { [progress, scale] }
}
