//
//  C7FilterTexture.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation
import MetalKit

public struct C7FilterTexture {
    
    public private(set) var inputTexture: MTLTexture
    public private(set) var destTexture: MTLTexture
    
    public init(texture: MTLTexture) {
        inputTexture = texture
        destTexture = texture
    }
    
    /// Convert to image output.
    /// - Returns: output image
    public func outputImage() -> C7Image? {
        return destTexture.toImage()
    }
}

extension C7FilterTexture: C7FilterOutput {
    
    public mutating func make<T>(filter: C7FilterProtocol) throws -> T where T : C7FilterOutput {
        do {
            let otherTextures = filter.otherInputTextures
            destTexture = try newTexture(inTexture: inputTexture, otherTextures: otherTextures, filter: filter)
            return self as! T
        } catch {
            throw error
        }
    }
    
    public mutating func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : C7FilterOutput {
        do {
            var outTexture: MTLTexture = self.inputTexture
            for filter in filters {
                let otherTextures = filter.otherInputTextures
                outTexture = try newTexture(inTexture: outTexture, otherTextures: otherTextures, filter: filter)
            }
            destTexture = outTexture
            return self as! T
        } catch {
            throw error
        }
    }
}

extension C7FilterTexture {
    mutating func updateInputTexture(_ texture: MTLTexture) {
        inputTexture = texture
    }
}
