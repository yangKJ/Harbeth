//
//  C7FlexoDest.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//

import Foundation
import MetalKit
import UIKit

/// 多功能处理器，目前支持`UIImage、CGImage、CIImage、MTLTexture`
/// Multifunctional processor, currently support `UIImage, CGImage、CIImage、MTLTexture`
///
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
                return try filtering(texture: element) as! Dest
            }
            if CFGetTypeID(element as CFTypeRef) == CGImage.typeID {
                return try filtering(cgImage: element as! CGImage) as! Dest
            }
            if let element = element as? CIImage {
                return try filtering(ciImage: element) as! Dest
            }
        } catch {
            throw error
        }
        return element
    }
}

// MARK: - filtering methods
extension C7FlexoDest {
    
    func filtering(ciImage: CIImage) throws -> CIImage {
        if let _ = filterEmpty(target: element) {
            return ciImage
        }
        guard let texture = ciImage.cgImage?.mt.newTexture() else {
            throw C7CustomError.source2Texture
        }
        ciImage.mt.renderImageToTexture(texture, context: Device.context())
        if let ciImg = CIImage(mtlTexture: texture) {
            if #available(iOS 11.0, *) {
                // When the CIImage is created, it is mirrored and flipped upside down.
                // But upon inspecting the texture, it still renders the CIImage as expected.
                // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
                return ciImg.oriented(.downMirrored)
            }
            return ciImg
        }
        return ciImage
    }
    
    func filtering(cgImage: CGImage) throws -> CGImage {
        if let _ = filterEmpty(target: element) {
            return cgImage
        }
        guard var texture = cgImage.mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            let pixelFormat = hasBitmap ? .bgra8Unorm : texture.pixelFormat
            return texture.toCGImage(pixelFormat: pixelFormat) ?? cgImage
        } catch {
            throw error
        }
    }
    
    func filtering(image: C7Image) throws -> C7Image {
        if let _ = filterEmpty(target: element) {
            return image
        }
        guard var texture = image.mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            return try fixImageOrientation(texture: texture, base: image)
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

// MARK: - private methods
extension C7FlexoDest {
    private func fixImageOrientation(texture: MTLTexture, base: C7Image) throws -> C7Image {
        let pixelFormat = hasBitmap ? .bgra8Unorm : texture.pixelFormat
        guard let cgImage = texture.toCGImage(pixelFormat: pixelFormat) else {
            throw C7CustomError.texture2Image
        }
        // Fixed an issue with HEIC flipping after adding filter.
        return C7Image(cgImage: cgImage, scale: base.scale, orientation: base.imageOrientation)
    }
    
    private func filterEmpty(target: Dest) -> Dest? {
        return filters.isEmpty ? target : nil
    }
}
