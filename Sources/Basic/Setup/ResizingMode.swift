//
//  ResizingMode.swift
//  Harbeth
//
//  Created by Condy on 2023/12/1.
//

import Foundation

/// Mainly for the image filling content to change the size.
public enum ResizingMode: Int, @unchecked Sendable {
    /// Scale the content to fill the size, possibly changing aspect ratio.
    case scaleToFill = 1
    
    /// Scale to fit with fixed aspect ratio; remainder is transparent (letterboxing).
    case scaleAspectFit = 2
    
    /// Scale to fill with fixed aspect ratio; center-crop (some content clipped).
    case scaleAspectFill = 3
    
    /// Scale to fill with fixed aspect ratio; align to bottom-right (top/left clipped).
    case scaleAspectBottomRight = 4
    
    /// Scale to fill with fixed aspect ratio; align to top-left (bottom/right clipped).
    case scaleAspectTopLeft = 5
    
    /// Do nothing — keep original image as-is.
    case own = 6
}

extension ResizingMode {
    
    /// Resize an image to the specified size based on the resizing mode.
    /// - Parameters:
    ///   - image: The input image.
    ///   - size: Target size. If `.zero`, returns the original image.
    /// - Returns: Resized (and possibly cropped) image.
    public func resizeImage(_ image: C7Image, size: CGSize) -> C7Image {
        if size == .zero || self == .own { return image }
        let imageSize = image.size
        let renderRect = setupRenderRect(targetSize: size, sourceSize: imageSize)
        guard !renderRect.isEmpty else {
            return image
        }
        let scaledImage = image.c7.renderer(rect: renderRect, canvas: renderRect.size)
        return cropIfNeeded(scaledImage, renderRect: renderRect, targetSize: size)
    }
    
    /// Computes the rectangle (in points) that the source image should be rendered into,
    /// before optional cropping to `targetSize`.
    private func setupRenderRect(targetSize: CGSize, sourceSize: CGSize) -> CGRect {
        switch self {
        case .scaleToFill:
            return CGRect(origin: .zero, size: targetSize)
        case .scaleAspectFit:
            let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
            let newSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            return CGRect(origin: .zero, size: newSize)
        case .scaleAspectFill, .scaleAspectBottomRight, .scaleAspectTopLeft:
            let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
            let newSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            return CGRect(origin: .zero, size: newSize)
        default:
            return .zero
        }
    }
    
    /// Applies final cropping based on alignment mode.
    private func cropIfNeeded(_ image: C7Image, renderRect: CGRect, targetSize: CGSize) -> C7Image {
        guard let cgImage = image.cgImage else { return image }
        guard [.scaleAspectFill, .scaleAspectBottomRight, .scaleAspectTopLeft].contains(self) else {
            return image
        }
        let renderedSize = renderRect.size
        guard renderedSize.width >= targetSize.width && renderedSize.height >= targetSize.height else {
            return image
        }
        let dx = renderedSize.width - targetSize.width
        let dy = renderedSize.height - targetSize.height
        let origin: CGPoint = {
            switch self {
            case .scaleAspectFill:
                return CGPoint(x: dx * 0.5, y: dy * 0.5)
            case .scaleAspectBottomRight:
                return CGPoint(x: dx, y: dy) // align bottom-right → crop top-left
            case .scaleAspectTopLeft:
                return .zero // align top-left → crop bottom-right
            default:
                return .zero
            }
        }()
        let cropRect = CGRect(origin: origin, size: targetSize)
        guard let croppedCG = cgImage.cropping(to: cropRect) else {
            return image
        }
        return croppedCG.c7.drawing(refImage: image)
    }
}
