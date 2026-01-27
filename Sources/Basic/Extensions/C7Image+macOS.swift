import Foundation

#if os(macOS)
import AppKit

// https://developer.apple.com/documentation/appkit/nsimage

extension C7Image {
    // Initialize with CGImage using zero size
    public convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
    
    // Initialize with CGImage, scale and orientation
    public convenience init(cgImage: CGImage, scale: CGFloat, orientation: C7ImageOrientation) {
        let processedImage = orientation != .up ? cgImage.c7.fixOrientation(from: orientation) : cgImage
        let imageRep = NSBitmapImageRep(cgImage: processedImage)
        let scale = max(1.0, scale)
        let width = CGFloat(imageRep.pixelsWide) / scale
        let height = CGFloat(imageRep.pixelsHigh) / scale
        self.init(cgImage: processedImage, size: .init(width: width, height: height))
        self.addRepresentation(imageRep)
    }
    
    // Get CGImage representation
    public var cgImage: CGImage? {
        var rect = NSRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    
    // Get image scale based on representation
    public var scale: CGFloat {
        guard let pixelsWide = representations.first?.pixelsWide else { return 1.0 }
        return CGFloat(pixelsWide) / size.width
    }
    
    // Generate PNG data from image
    public func pngData() -> Data? {
        guard let rep = tiffRepresentation, let bitmap = NSBitmapImageRep(data: rep) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    // Generate JPEG data with compression quality
    public func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let rep = tiffRepresentation, let bitmap = NSBitmapImageRep(data: rep) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    // Generate HEIC data (macOS 10.13+)
    public func heic() -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.heic" as CFString, 1, nil),
              let cgImage = cgImage else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination) ? mutableData as Data : nil
    }
}

extension HarbethWrapper where Base: C7Image {
    // Calculate actual image size from representations
    public var size: CGSize {
        return base.representations.reduce(.zero) { size, rep in
            let width = max(size.width, CGFloat(rep.pixelsWide))
            let height = max(size.height, CGFloat(rep.pixelsHigh))
            return CGSize(width: width, height: height)
        }
    }
    
    /// Flip image transformation (must be used within base.lockFocus())
    /// - Parameters:
    ///   - horizontal: Horizontal flip flag
    ///   - vertical: Vertical flip flag
    public func flip(horizontal: Bool = true, vertical: Bool = true) {
        guard horizontal || vertical else { return }
        var tx = base.size.width, ty = base.size.height
        var sx: CGFloat = -1, sy: CGFloat = -1
        if horizontal && !vertical {
            tx = 0; sx = 1
        } else if !horizontal && vertical {
            ty = 0; sy = 1
        }
        let transform = NSAffineTransform()
        transform.translateX(by: tx, yBy: ty)
        transform.scaleX(by: sx, yBy: sy)
        transform.concat()
    }
}
#endif
