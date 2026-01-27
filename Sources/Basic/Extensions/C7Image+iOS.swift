//
//  C7Image+iOS.swift
//  Harbeth
//
//  Created by Condy on 2023/1/30.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

extension HarbethWrapper where Base: C7Image {
    /// Generate compressed JPEG data with optional maximum size constraint
    /// - Parameter maxCount: Maximum allowed file size in bytes (0 means unlimited)
    /// - Returns: Compressed JPEG data
    public func jpegData(maxCount: Int = 0) -> Data? {
        var quality = CGFloat(1)
        var jpegData = base.jpegData(compressionQuality: quality)
        while let data = jpegData, maxCount > 0 && data.count > maxCount && quality > 0 {
            quality -= 0.05
            jpegData = base.jpegData(compressionQuality: quality)
        }
        return jpegData
    }
    
    /// Returns image with original rendering mode (prevents tint color application)
    public var original: C7Image {
        base.withRenderingMode(.alwaysOriginal)
    }
    
    /// Create a copy with specified JPEG compression quality
    /// - Parameter compressionQuality: Compression quality (0.0 to 1.0)
    /// - Returns: New image instance with applied compression
    public func copy(compressionQuality: CGFloat) -> C7Image? {
        base.jpegData(compressionQuality: compressionQuality).flatMap { C7Image(data: $0) }
    }
    
    /// Remove white background by making pixels in range [222...255] transparent
    /// - Returns: Image with transparent white background
    public func imageByMakingWhiteBackgroundTransparent() -> C7Image? {
        transparentColor(colorMasking: [222, 255, 222, 255, 222, 255])
    }
    
    /// Remove black background by making pixels in range [0...32] transparent
    /// - Returns: Image with transparent black background
    public func imageByRemoveBlackBg() -> C7Image? {
        transparentColor(colorMasking: [0, 32, 0, 32, 0, 32])
    }
    
    /// Make specified color ranges transparent
    /// - Parameters:
    ///   - colorMasking: Color component ranges [R-min, R-max, G-min, G-max, B-min, B-max]
    ///   - compressionQuality: JPEG compression quality (default: 1.0)
    /// - Returns: Image with transparent background
    public func transparentColor(colorMasking: [CGFloat], compressionQuality: CGFloat = 1.0) -> C7Image? {
        UIGraphicsBeginImageContext(base.size)
        defer { UIGraphicsEndImageContext() }
        
        guard let maskedImageRef = base.cgImage?.copy(maskingColorComponents: colorMasking),
              let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let rect = CGRect(origin: .zero, size: base.size)
        context.translateBy(x: 0, y: base.size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(maskedImageRef, in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Change image line color while preserving transparency
    /// - Parameter color: Target line color
    /// - Returns: Recolored image
    public func line(color: C7Color) -> C7Image {
        blend(mode: .destinationIn, tinted: color)
    }
    
    /// Blend image with color using specified blend mode
    /// - Parameters:
    ///   - mode: CGBlendMode to apply
    ///   - color: Tint color
    /// - Returns: Blended image
    public func blend(mode: CGBlendMode, tinted color: C7Color) -> C7Image {
        let rect = CGRect(origin: .zero, size: base.size)
        return UIGraphicsImageRenderer(size: base.size).image { _ in
            color.setFill()
            UIRectFill(rect)
            base.draw(in: rect, blendMode: mode, alpha: 1)
            if mode != .destinationIn {
                base.draw(in: rect, blendMode: .destinationIn, alpha: 1)
            }
        }
    }
    
    /// Circular crop to smallest dimension
    public var circled: C7Image {
        let minEdge = min(base.size.width, base.size.height)
        let size = CGSize(width: minEdge, height: minEdge)
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.addEllipse(in: CGRect(origin: .zero, size: size))
            context.cgContext.clip()
            base.draw(in: CGRect(origin: .zero, size: base.size))
        }
    }
    
    /// Crop to square from center
    public var squared: C7Image {
        let edge = min(base.size.width, base.size.height)
        let difference = base.size.width - base.size.height
        let x = difference > 0 ? abs(difference/2) : 0
        let y = difference < 0 ? abs(difference/2) : 0
        let cropSquare = CGRect(x: x, y: y, width: edge, height: edge)
        guard let imageRef = base.cgImage?.cropping(to: cropSquare) else { return base }
        return C7Image(cgImage: imageRef, scale: base.scale, orientation: base.imageOrientation)
    }
    
    /// Create resizable image with stretchable edges
    /// - Parameter edges: Cap insets for stretching
    /// - Returns: Resizable image
    public func stretchImage(edges: UIEdgeInsets) -> C7Image {
        base.resizableImage(withCapInsets: edges, resizingMode: .stretch)
    }
    
    /// Crop outside of bezier path
    /// - Parameter bezierPath: Path to preserve
    /// - Returns: Cropped image
    public func cropOuter(bezierPath: UIBezierPath) -> C7Image {
        guard !bezierPath.isEmpty else { return base }
        let rect = CGRect(origin: .zero, size: base.size)
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            let outer = CGMutablePath()
            outer.addRect(rect)
            outer.addPath(bezierPath.cgPath)
            context.cgContext.addPath(outer)
            context.cgContext.setBlendMode(.clear)
            base.draw(in: rect)
            context.cgContext.drawPath(using: .eoFill)
        }
    }
    
    /// Crop inside of bezier path
    /// - Parameter bezierPath: Path to remove
    /// - Returns: Cropped image
    public func cropInner(bezierPath: UIBezierPath) -> C7Image {
        guard !bezierPath.isEmpty else { return base }
        let rect = CGRect(origin: .zero, size: base.size)
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            context.cgContext.setBlendMode(.clear)
            base.draw(in: rect)
            context.cgContext.addPath(bezierPath.cgPath)
            context.cgContext.drawPath(using: .eoFill)
        }
    }
    
    /// Fit image to target dimensions while preserving aspect ratio
    /// - Parameters:
    ///   - width: Target width (0 preserves original)
    ///   - height: Target height (0 preserves original)
    /// - Returns: Fitted image
    public func fitFixed(width: CGFloat = 0, height: CGFloat = 0) -> C7Image {
        guard let cgImage = base.cgImage else { return base }
        
        var rect = CGRect(origin: .zero, size: base.size)
        switch (width, height) {
        case (0, 0): return base
        case (0, _) where height > 0:
            rect.size.width = base.size.width * (height / base.size.height)
            rect.size.height = height
        case (_, 0) where width > 0:
            rect.size.width = width
            rect.size.height = base.size.height * (width / base.size.width)
        default:
            if base.size.width/base.size.height < width/height {
                rect.size.height = height
                rect.size.width = base.size.width * height / base.size.height
                rect.origin.x = (width - rect.size.width) * 0.5
            } else {
                rect.size.width = width
                rect.size.height = base.size.height * width / base.size.width
                rect.origin.y = -(height - rect.size.height) * 0.5
            }
        }
        
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            context.cgContext.translateBy(x: 0, y: rect.size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.setBlendMode(.copy)
            context.cgContext.draw(cgImage, in: rect)
        }
    }
}

#endif
