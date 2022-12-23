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
    /// Fixed image rotation direction.
    public func fixOrientation() -> C7Image {
        #if os(iOS) || os(tvOS) || os(watchOS)
        if base.imageOrientation == .up {
            return base
        }
        let width  = base.size.width
        let height = base.size.height
        var transform = CGAffineTransform.identity
        
        switch base.imageOrientation {
        case .down, .downMirrored:
            transform = CGAffineTransform(translationX: width, y: height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = CGAffineTransform(translationX: width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2)
        case .right, .rightMirrored:
            transform = CGAffineTransform(translationX: 0, y: height)
            transform = transform.rotated(by: -CGFloat.pi / 2)
        default:
            break
        }
        
        switch base.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        guard let cgImage = base.cgImage, let colorSpace = cgImage.colorSpace else {
            return base
        }
        let context = CGContext(data: nil,
                                width: Int(width),
                                height: Int(height),
                                bitsPerComponent: cgImage.bitsPerComponent,
                                bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: cgImage.bitmapInfo.rawValue)
        context?.concatenate(transform)
        switch base.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        guard let newCgImage = context?.makeImage() else {
            return base
        }
        return newCgImage.mt.toC7Image()
        #else
        return base
        #endif
    }
    
    /// To ensure image orientation is correct, redraw image if image orientation is not up.
    /// see: https://stackoverflow.com/questions/42098390/swift-png-image-being-saved-with-incorrect-orientation
    #if os(iOS) || os(tvOS) || os(watchOS)
    public var flattened: C7Image {
        if base.imageOrientation == .up { return base.copy() as! C7Image }
        UIGraphicsBeginImageContextWithOptions(base.size, false, base.scale)
        base.draw(in: CGRect(origin: .zero, size: base.size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
    #endif
    
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
