//
//  Transform.swift
//  Harbeth
//
//  Created by Condy on 2022/2/28.
//

import Foundation
import MetalKit
import CoreImage

extension C7Image: C7Compatible { }

extension Queen where Base == C7Image {
    
    /// Image to texture
    ///
    /// Texture loader can not load image data to create texture
    /// Draw image and create texture
    /// - Returns: MTLTexture
    public func toTexture(cgimage: CGImage? = nil) -> MTLTexture? {
        return (cgimage ?? base.cgImage)?.mt.toTexture()
    }
    
    public func toCIImage() -> CIImage? {
        #if os(iOS) || os(tvOS) || os(watchOS)
        if let ciImage = base.ciImage {
            return ciImage
        }
        return CIImage(image: base)
        #else
        if let cgImage = base.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
        #endif
    }
}

// MARK: - edit image
extension Queen where Base: C7Image {
    /// Modify image size.
    /// - Parameters:
    ///   - size: Target size.
    ///   - equalRatio: Whether to use the original image ratio.
    ///   - scale: Image scale.
    /// - Returns: Return a new image.
    public func zipScale(size: CGSize, equalRatio: Bool = false, scale: CGFloat? = nil) -> C7Image {
        if __CGSizeEqualToSize(base.size, size) {
            return base
        }
        let rect: CGRect
        if size.width / size.height != base.size.width / base.size.height && equalRatio {
            let scale = size.width / base.size.width
            var sh = scale * base.size.height
            var sw = size.width
            if sh < size.height {
                sw = size.height / sh * size.width
                sh = size.height
            }
            rect = CGRect(x: -(sw - size.height) * 0.5, y: -(sh - size.height) * 0.5, width: sw, height: sh)
        } else {
            rect = CGRect(origin: .zero, size: size)
        }
        #if os(iOS) || os(tvOS) || os(watchOS)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale ?? base.scale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let image = renderer.image { _ in base.draw(in: rect) }
        return image
        #elseif os(macOS)
        let _rect = NSRect(origin: rect.origin, size: rect.size)
        let image = NSImage.init(size: _rect.size)
        image.lockFocus()
        defer { image.unlockFocus() }
        base.draw(in: _rect, from: .zero, operation: .sourceOver, fraction: scale ?? base.scale)
        return image
        #else
        return base
        #endif
    }
}
