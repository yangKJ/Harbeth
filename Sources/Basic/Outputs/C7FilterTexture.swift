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
    
    mutating func updateInputTexture(_ texture: MTLTexture) {
        inputTexture = texture
    }
}

extension C7FilterTexture: C7FilterDestProtocol {
    
    public mutating func make<T>(filter: C7FilterProtocol) throws -> T where T : C7FilterDestProtocol {
        do {
            destTexture = try Processed.generateOutTexture(inTexture: inputTexture, filter: filter)
            return self as! T
        } catch {
            throw error
        }
    }
    
    public mutating func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : C7FilterDestProtocol {
        do {
            var outTexture: MTLTexture = inputTexture
            for filter in filters {
                outTexture = try Processed.generateOutTexture(inTexture: outTexture, filter: filter)
            }
            destTexture = outTexture
            return self as! T
        } catch {
            throw error
        }
    }
}
