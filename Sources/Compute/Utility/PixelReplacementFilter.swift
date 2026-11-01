//
//  PixelReplacementFilter.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import Foundation

/// Replaces a blurred pixel against the original pixel using an optional coverage texture.
public struct PixelReplacementFilter: C7FilterProtocol {
    public let originalTexture: MTLTexture
    public let selectionTexture: MTLTexture?
    public let opacity: Float
    public let preservesTransparency: Bool

    public var modifier: ModifierEnum { .compute(kernel: "PixelReplacementFilter") }
    public var factors: [Float] { [opacity, preservesTransparency ? 1 : 0] }
    public var otherInputTextures: C7InputTextures {
        [originalTexture, selectionTexture ?? originalTexture]
    }
    public var memoryAccessPattern: MemoryAccessPattern { .multiTexture }
    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "opacity", index: 0, stage: .compute, value: .float(opacity)),
            KernelParameterBinding(name: "preservesTransparency", index: 1, stage: .compute, value: .bool(preservesTransparency)),
            KernelParameterBinding(name: "usesSelection", index: 2, stage: .compute, value: .bool(selectionTexture != nil))
        ]
    }

    public init(originalTexture: MTLTexture, selectionTexture: MTLTexture?, opacity: Float, preservesTransparency: Bool) throws {
        guard opacity.isFinite, (0...1).contains(opacity) else {
            throw HarbethError.filterParameterInvalid("PixelReplacementFilter opacity must be finite and in [0, 1].")
        }
        self.originalTexture = originalTexture
        self.selectionTexture = selectionTexture
        self.opacity = opacity
        self.preservesTransparency = preservesTransparency
    }
}
