//
//  C7Image+iOS.swift
//  Harbeth
//
//  Created by Condy on 2023/1/30.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

// https://developer.apple.com/documentation/uikit/uiimage

extension HarbethWrapper where Base: C7Image {
    /// To ensure image orientation is correct, redraw image if image orientation is not up.
    /// See: https://stackoverflow.com/questions/42098390/swift-png-image-being-saved-with-incorrect-orientation
    public var flattened: C7Image {
        if base.imageOrientation == .up {
            return base.copy() as! C7Image
        }
        UIGraphicsBeginImageContextWithOptions(base.size, false, base.scale)
        base.draw(in: CGRect(origin: .zero, size: base.size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
    
    /// Fixed image rotation direction.
    public func fixOrientation() -> C7Image {
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
        
        guard let cgImage_ = context?.makeImage() else {
            return base
        }
        return cgImage_.c7.toC7Image()
    }
    
    /// Compressed image data.
    /// - Parameter maxCount: Maximum compression ratio.
    /// - Returns: Compressed content data.
    public func jpegData(maxCount: Int = 0) -> Data? {
        var quality = CGFloat(1)
        var jpegData = base.jpegData(compressionQuality: quality)
        while let data = jpegData, maxCount > 0 && data.count > maxCount && quality > 0 {
            quality -= 0.05
            jpegData = base.jpegData(compressionQuality: quality)
        }
        return jpegData
    }
}

extension HarbethWrapper where Base: C7Image {
    /// 白色背景透明化，色值在[222...255]之间均可祛除
    /// The white background is transparent, and the color value can be removed between [222...255].
    public func imageByMakingWhiteBackgroundTransparent() -> C7Image? {
        // RGB color range to mask (make transparent) R-Low, R-High, G-Low, G-High, B-Low, B-High
        let colorMasking: [CGFloat] = [222, 255, 222, 255, 222, 255]
        return transparentColor(colorMasking: colorMasking)
    }
    
    /// 黑色背景透明化，色值在[0...32]之间均可祛除
    public func imageByRemoveBlackBg() -> C7Image? {
        let colorMasking: [CGFloat] = [0, 32, 0, 32, 0, 32]
        return transparentColor(colorMasking: colorMasking)
    }
    
    /// Transparent background.
    /// - Parameters:
    ///   - colorMasking: RGB color range to mask [R-Low, R-High, G-Low, G-High, B-Low, B-High]
    ///   - compressionQuality: Compression ratio.
    /// - Returns: Remove the picture of the background.
    public func transparentColor(colorMasking: [CGFloat], compressionQuality: CGFloat = 1.0) -> C7Image? {
        // 解决前面有绘制过Bitmap《UIGraphicsGetCurrentContext》，导致失效问题
        guard let data = base.jpegData(compressionQuality: compressionQuality),
              let image = C7Image(data: data) else {
            return nil
        }
        UIGraphicsBeginImageContext(image.size)
        guard let maskedImageRef = image.cgImage?.copy(maskingColorComponents: colorMasking) else {
            return nil
        }
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0.0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.draw(maskedImageRef, in: rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    /// Rotate the picture.
    /// - Parameter degrees: Rotation angle.
    /// - Returns: The picture after rotation.
    public func rotate(degrees: Float) -> C7Image {
        let radians = CGFloat(degrees) / 180.0 * .pi
        let tran = CGAffineTransform(rotationAngle: radians)
        var size = CGRect(origin: .zero, size: base.size).applying(tran).size
        size.width  = floor(size.width)
        size.height = floor(size.height)
        let rect = CGRect(x: -base.size.width/2, y: -base.size.height/2, width: base.size.width, height: base.size.height)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: size.width/2, y: size.height/2)
        context?.rotate(by: radians)
        base.draw(in: rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
    
    /// Round image.
    public var circle: C7Image {
        let min = min(base.size.width, base.size.height)
        let size = CGSize(width: min, height: min)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context?.addEllipse(in: .init(origin: .zero, size: size))
        context?.clip()
        base.draw(in: .init(origin: .zero, size: base.size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
    
    
    /// Modify the line color of the picture.
    /// - Parameter color: Line color.
    public func line(color: C7Color) -> C7Image {
        blend(mode: .destinationIn, tinted: color)
    }
    
    /// Mixing color.
    public func blend(mode: CGBlendMode, tinted color: C7Color) -> C7Image {
        UIGraphicsBeginImageContextWithOptions(base.size, false, 0.0)
        color.setFill()
        let rect = CGRect(origin: .zero, size: base.size)
        UIRectFill(rect)
        base.draw(in: rect, blendMode: mode, alpha: 1.0)
        if mode != .destinationIn {
            base.draw(in: rect, blendMode: .destinationIn, alpha: 1.0)
        }
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage ?? base
    }
    
    /// Fill the image on the basis that the image is not deformed.
    /// - Parameters:
    ///   - width: Fill image width, Keep the original size at zero.
    ///   - height: Fill image height, Keep the original size at zero.
    public func fitFixed(width: CGFloat = 0, height: CGFloat = 0) -> C7Image {
        guard let cgImage = base.cgImage else {
            return base
        }
        var rect = CGRect(origin: .zero, size: base.size)
        switch (width, height) {
        case (0.0, 0.0):
            return base
        case (0.0, 0.0000002...):
            rect.size.width = base.size.width * (height / base.size.height)
            rect.size.height = height
        case (0.0000002..., 0.0):
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
        UIGraphicsBeginImageContextWithOptions(rect.size, false, base.scale)
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0.0, y: rect.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.setBlendMode(.copy)
        context?.draw(cgImage, in: rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
}

extension HarbethWrapper where Base: C7Image {
    /// Image path cropping, cropping path outside part.
    /// - Parameter bezierPath: Crop path.
    public func cropOuter(bezierPath: UIBezierPath) -> C7Image {
        guard !bezierPath.isEmpty else {
            return base
        }
        let rect = CGRect(x: 0, y: 0, width: base.size.width, height: base.size.height)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        let outer = CGMutablePath()
        outer.addRect(rect, transform: .identity)
        outer.addPath(bezierPath.cgPath, transform: .identity)
        context?.addPath(outer)
        context?.setBlendMode(.clear)
        base.draw(in: rect)
        context?.drawPath(using: .eoFill)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
    
    /// Image path cropping, cropping path inner part.
    /// - Parameter bezierPath: Crop path.
    public func cropInner(bezierPath: UIBezierPath) -> C7Image {
        guard !bezierPath.isEmpty else {
            return base
        }
        let rect = CGRect(x: 0, y: 0, width: base.size.width, height: base.size.height)
        //UIGraphicsBeginImageContextWithOptions(rect.size, false, base.scale)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setBlendMode(.clear)
        base.draw(in: rect)
        context?.addPath(bezierPath.cgPath)
        context?.drawPath(using: .eoFill)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
    }
}

#endif
