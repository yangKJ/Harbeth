//
//  C7CombinationBase.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// Base class for combination filters, providing common functionality
open class C7CombinationBase: C7FilterProtocol {
    
    /// Intermediate textures used by the combination filter
    public var intermediateTextures: [MTLTexture] = []
    
    /// Encoder type and corresponding function name.
    open var modifier: ModifierEnum {
        fatalError("Subclasses must override")
    }
    
    /// The supports a maximum of 16 `Float` parameters.
    open var factors: [Float] {
        []
    }
    
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    open var otherInputTextures: C7InputTextures {
        []
    }
    
    /// Do you need the total number of pixels factor,
    /// before the special factor and after the factors.
    open var hasCount: Bool {
        false
    }
    
    /// The resize of the output texture.
    open func resize(input size: C7Size) -> C7Size {
        size
    }
    
    /// Special type of parameter factor, such as 4x4 matrix
    open func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) { }
    
    /// If you need to replace the subsequent input source texture, return to a new texture with copied to dest.
    open func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        _ = try prepareIntermediateTextures(buffer: buffer, source: texture)
        return texture
    }
    
    /// Combination output metal texture, support `compute`, `render` and `mps` type.
    open func combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture {
        cleanupIntermediateTextures()
        return texture
    }
    
    /// Prepare intermediate textures for the combination filter
    open func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        []
    }
    
    /// Cleanup intermediate textures
    open func cleanupIntermediateTextures() {
        // Subclasses can override to clean up specific resources
        intermediateTextures.removeAll()
    }
}
