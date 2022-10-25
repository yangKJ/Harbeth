//
//  C7FlexoDest.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//

import Foundation
import MetalKit
import UIKit

/// 多功能处理器，目前支持`UIImage、CGImage、MTLTexture`
/// Multifunctional processor, currently support `UIImage, CGImage、MTLTexture`
@frozen public struct C7FlexoDest<Dest> : Destype {
    public typealias Element = Dest
    public var element: Dest
    public var filters: [C7FilterProtocol]
    
    /// 是否提前绘制过图片
    /// Whether the picture has been drawn in advance.
    public var hasBitmap: Bool = false
    
    public init(element: Dest, filters: [C7FilterProtocol]) {
        self.element = element
        self.filters = filters
    }
    
    public func output() throws -> Dest {
        do {
            if let element = element as? C7Image {
                return try filtering(image: element) as! Dest
            }
            if let element = element as? MTLTexture {
                return try  filtering(texture: element) as! Dest
            }
        } catch {
            throw error
        }
        return element
    }
}

extension C7FlexoDest {
    
    func filtering(image: C7Image) throws -> C7Image {
        guard var texture = image.mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            return try Self.fixImageOrientation(texture: texture, base: image)
        } catch {
            throw error
        }
    }
    
    func filtering(texture: MTLTexture) throws -> MTLTexture {
        do {
            var outTexture: MTLTexture = texture
            for filter in filters {
                outTexture = try Processed.IO(inTexture: outTexture, filter: filter)
            }
            return outTexture
        } catch {
            throw error
        }
    }
}

extension C7FlexoDest {
    static func fixImageOrientation(texture: MTLTexture, base: C7Image) throws -> C7Image {
        guard let cgImage = texture.toCGImage() else {
            throw C7CustomError.texture2Image
        }
        // Fixed an issue with HEIC flipping after adding filter.
        return C7Image(cgImage: cgImage, scale: base.scale, orientation: base.imageOrientation)
    }
}
