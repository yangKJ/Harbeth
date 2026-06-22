//
//  TransitionFilters.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

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
