//
//  ResizingMode.swift
//  Harbeth
//
//  Created by Condy on 2023/12/1.
//

import Foundation

/// Mainly for the image filling content to change the size.
public enum ResizingMode: Int, @unchecked Sendable  {
    /// Dimensions of the original image. do nothing with it.
    case original = 0
    /// The option to scale the content to fit the size of itself by changing the aspect ratio of the content if necessary.
    case scaleToFill = 1
    /// Contents scaled to fit with fixed aspect. remainder is transparent.
    case scaleAspectFit = 2
    /// Contents scaled to fill with fixed aspect. some portion of content may be clipped.
    case scaleAspectFill = 3
    /// Contents scaled to fill with fixed aspect. top or left portion of content may be clipped.
    case scaleAspectBottomRight = 4
    /// Contents scaled to fill with fixed aspect. bottom or right portion of content may be clipped.
    case scaleAspectTopLeft = 5
}

extension ResizingMode {
    
    /// Resize an image to the specified size. Depending on what fitMode is supplied
    /// - Parameters:
    ///   - image: Image to resize.
    ///   - size: Size to resize the image to. it is `.zero` return original image.
    /// - Returns: Resized image.
    public func resizeImage(_ image: C7Image?, size: CGSize) -> C7Image? {
        guard let image = image else {
            return nil
        }
        if case .original = self, size == .zero {
            return image
        }
        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        var rect = CGRect(origin: .zero, size: image.size)
        switch self {
        case .scaleToFill:
            rect.size = size
        case .scaleAspectFit:
            let ratio = min(horizontalRatio, verticalRatio)
            rect.size = CGSize(width: rect.size.width * ratio, height: rect.size.height * ratio)
        case .scaleAspectFill, .scaleAspectBottomRight, .scaleAspectTopLeft:
            let ratio = max(horizontalRatio, verticalRatio)
            rect.size = CGSize(width: rect.size.width * ratio, height: rect.size.height * ratio)
        default:
            return image
        }
        let omimage = drawImage(image, rect: rect)
        return cropingImage(omimage, rect: rect, targetSize: size)
    }
    
    private func cropingImage(_ image: C7Image, rect: CGRect, targetSize: CGSize) -> C7Image {
        var cropRect: CGRect
        switch self {
        case .scaleAspectFill:
            let x = (rect.size.width - targetSize.width) * 0.5
            let y = (rect.size.height - targetSize.height) * 0.5
            cropRect = CGRect(x: x, y: y, width: rect.size.width - 2 * x, height: rect.size.height - 2 * y)
        case .scaleAspectBottomRight:
            let x = (rect.size.width - targetSize.width) * 0.5
            let y = (rect.size.height - targetSize.height) * 0.5
            cropRect = CGRect(origin: CGPoint(x: x, y: y), size: rect.size)
            cropRect = cropRect.offsetBy(dx: x, dy: y)
        case .scaleAspectTopLeft:
            let x = (rect.size.width - targetSize.width) * 0.5
            let y = (rect.size.height - targetSize.height) * 0.5
            cropRect = CGRect(x: 0, y: 0, width: rect.size.width - 2 * x, height: rect.size.height - 2 * y)
        default:
            return image
        }
        return (image.cgImage?.cropping(to: cropRect)?.c7.toC7Image()) ?? image
    }
    
    private func drawImage(_ base: C7Image, rect: CGRect) -> C7Image {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let image = renderer.image { _ in base.draw(in: rect) }
        return image
        #elseif os(macOS)
        let _rect = NSRect(origin: rect.origin, size: rect.size)
        let image = NSImage.init(size: _rect.size)
        image.lockFocus()
        defer { image.unlockFocus() }
        base.draw(in: _rect, from: .zero, operation: .sourceOver, fraction: base.scale)
        return image
        #else
        return base
        #endif
    }
}
