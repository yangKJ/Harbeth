//
//  C7Image+macOS.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

#if os(macOS)
import AppKit

// https://developer.apple.com/documentation/appkit/nsimage

extension C7Image {
    
    public convenience init(cgImage: CGImage) {
        //self.init(cgImage: cgImage, scale: 1.0, orientation: .up)
        self.init(cgImage: cgImage, size: .zero)
    }
    
    public convenience init(cgImage: CGImage, scale: CGFloat, orientation: C7ImageOrientation) {
        let cgImage: CGImage = {
            orientation != .up ? cgImage.c7.fixOrientation(from: orientation) : cgImage
        }()
        let imageRep = NSBitmapImageRep(cgImage: cgImage)
        let scale = max(1.0, scale)
        let width = CGFloat(imageRep.pixelsWide) / scale
        let height = CGFloat(imageRep.pixelsHigh) / scale
        self.init(cgImage: cgImage, size: .init(width: width, height: height))
        self.addRepresentation(imageRep)
    }
    
    public var cgImage: CGImage? {
        var rect = NSRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    
    public var scale: CGFloat {
        guard let pixelsWide = representations.first?.pixelsWide else {
            return 1.0
        }
        let scale: CGFloat = CGFloat(pixelsWide) / size.width
        return scale
    }
    
    public func pngData() -> Data? {
        guard let rep = tiffRepresentation, let bitmap = NSBitmapImageRep(data: rep) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    public func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let representation = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: representation) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    public func heic() -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.heic" as CFString, 1, nil),
              let cgImage = cgImage else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}

extension HarbethWrapper where Base: C7Image {
    
    public var size: CGSize {
        return base.representations.reduce(.zero) { (size, rep) in
            let width  = max(size.width, CGFloat(rep.pixelsWide))
            let height = max(size.height, CGFloat(rep.pixelsHigh))
            return CGSize(width: width, height: height)
        }
    }
    
    /// Flip image, Need to be used in `base.lockFocus()`
    ///
    /// Example:
    ///
    ///     image.lockFocus()
    ///     image.c7.flip(horizontal: true, vertical: true)
    ///
    /// - Parameters:
    ///   - horizontal: Flip 180 degrees from left to right or right to left.
    ///   - vertical: Flip 180 degrees from top down or bottom up.
    public func flip(horizontal: Bool = true, vertical: Bool = true) {
        if horizontal == false && vertical == false { return }
        var tx = base.size.width
        var ty = base.size.height
        var sx: CGFloat = -1
        var sy: CGFloat = -1
        if horizontal, !vertical {
            tx = 0; sx = 1
        } else if !horizontal, vertical {
            ty = 0; sy = 1
        }
        let transform = NSAffineTransform.init(transform: .identity)
        transform.translateX(by: tx, yBy: ty)
        transform.scaleX(by: sx, yBy: sy)
        transform.concat()
    }
}
#endif
