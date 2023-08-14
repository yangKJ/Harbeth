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

extension Queen where Base: C7Image {
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

extension Queen where Base: C7Image {
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
    /// Fixed `UIImage(cgImage:scale:orientation:)` 在绘制过bitmap之后失效问题
    /// - Parameter degrees: Rotation angle.
    /// - Returns: The picture after rotation.
    public func rotate(degrees: Float) -> C7Image {
        let radians = CGFloat(degrees) / 180.0 * CGFloat.pi
        let width  = base.size.width
        let height = base.size.height
        var newSize = CGRect(origin: CGPoint.zero, size: base.size)
            .applying(CGAffineTransform(rotationAngle: radians)).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, base.scale)
        let context = UIGraphicsGetCurrentContext()
        // Move origin to middle
        context?.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context?.rotate(by: radians)
        // Draw the image at its center
        base.draw(in: CGRect(x: -width/2, y: -height/2, width: width, height: height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? base
    }
}

#endif
