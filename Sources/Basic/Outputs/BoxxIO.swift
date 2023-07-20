//
//  BoxxIO.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//  https://github.com/yangKJ/Harbeth

import Foundation
import MetalKit
import CoreImage
import CoreMedia
import CoreVideo

/// Quickly add filters to sources.
/// Support use `UIImage/NSImage, CGImage, CIImage, MTLTexture, CMSampleBuffer, CVPixelBuffer`
///
/// For example:
///
///     let filter = C7Storyboard(ranks: 2)
///     let dest = BoxxIO.init(element: originImage, filter: filter)
///     ImageView.image = try? dest.output()
///
///     // Asynchronous add filters to sources.
///     dest.transmitOutput(success: { [weak self] image in
///         // do somthing..
///     })
///
@frozen public struct BoxxIO<Dest> : Destype {
    public typealias Element = Dest
    public let element: Dest
    public let filters: [C7FilterProtocol]
    
    // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
    // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
    public var bufferPixelFormat: MTLPixelFormat = .bgra8Unorm
    
    // When the CIImage is created, it is mirrored and flipped upside down.
    // But upon inspecting the texture, it still renders the CIImage as expected.
    // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
    public var mirrored: Bool = false
    
    #if os(macOS)
    // Fixed an issue with HEIC flipping after adding filter.
    // If drawing a HEIC, we need to make context flipped.
    public var heic: Bool = false
    #endif
    
    public init(element: Dest, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }
    
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
            if CFGetTypeID(element as CFTypeRef) == CVPixelBufferGetTypeID() {
                return try filtering(pixelBuffer: element as! CVPixelBuffer) as! Dest
            }
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *),
               CFGetTypeID(element as CFTypeRef) == CMSampleBuffer.typeID {
                return try filtering(sampleBuffer: element as! CMSampleBuffer) as! Dest
            }
        } catch {
            throw error
        }
        return element
    }
    
    /// Asynchronous quickly add filters to sources.
    /// - Parameters:
    ///   - success: successful.
    ///   - failed: failed.
    public func transmitOutput(success: @escaping (Dest) -> Void, failed: ((Error) -> Void)? = nil) {
        if self.filters.isEmpty {
            success(element)
            return
        }
        if let element = element as? C7Image {
            guard let texture = element.mt.toTexture() else {
                failed?(C7CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    do {
                        let image = try fixImageOrientation(texture: t, base: element)
                        success(image as! Dest)
                    } catch {
                        failed?(error)
                    }
                case .failure(let error):
                    failed?(error)
                }
            }
        } else if let element = element as? MTLTexture {
            filtering(texture: element) { res in
                switch res {
                case .success(let t):
                    success(t as! Dest)
                case .failure(let error):
                    failed?(error)
                }
            }
        } else if CFGetTypeID(element as CFTypeRef) == CGImage.typeID {
            guard let texture = (element as! CGImage).mt.toTexture() else {
                failed?(C7CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    if let cgImage = t.mt.toCGImage() {
                        success(cgImage as! Dest)
                    }
                case .failure(let error):
                    failed?(error)
                }
            }
        } else if let element = element as? CIImage {
            guard let texture = element.cgImage?.mt.newTexture() else {
                failed?(C7CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    let ciImage = self.applyCIImage(element, with: t) as! Dest
                    success(ciImage)
                case .failure(let error):
                    failed?(error)
                }
            }
        } else if CFGetTypeID(element as CFTypeRef) == CVPixelBufferGetTypeID() {
            guard let texture = (element as! CVPixelBuffer).mt.toMTLTexture(textureCache: nil) else {
                failed?(C7CustomError.source2Texture)
                return
            }
            let pixelBuffer = element as! CVPixelBuffer
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    pixelBuffer.mt.copyToPixelBuffer(with: t)
                    success(pixelBuffer as! Dest)
                case .failure(let error):
                    failed?(error)
                }
            }
        } else if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *),
                  CFGetTypeID(element as CFTypeRef) == CMSampleBuffer.typeID {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer((element as! CMSampleBuffer)),
                  let texture = (element as! CVPixelBuffer).mt.toMTLTexture(textureCache: nil) else {
                failed?(C7CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    pixelBuffer.mt.copyToPixelBuffer(with: t)
                    if let sampleBuffer = pixelBuffer.mt.toCMSampleBuffer() {
                        success(sampleBuffer as! Dest)
                    }
                case .failure(let error):
                    failed?(error)
                }
            }
        }
    }
}

// MARK: - filtering methods
extension BoxxIO {
    
    func filtering(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        if self.filters.isEmpty { return pixelBuffer }
        guard var texture = pixelBuffer.mt.toMTLTexture(textureCache: nil) else {
            throw C7CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            pixelBuffer.mt.copyToPixelBuffer(with: texture)
            return pixelBuffer
        } catch {
            throw error
        }
    }
    
    func filtering(sampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer {
        if self.filters.isEmpty { return sampleBuffer }
        guard var pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw C7CustomError.source2Texture
        }
        do {
            pixelBuffer = try filtering(pixelBuffer: pixelBuffer)
            return pixelBuffer.mt.toCMSampleBuffer() ?? sampleBuffer
        } catch {
            throw error
        }
    }
    
    func filtering(ciImage: CIImage) throws -> CIImage {
        if self.filters.isEmpty { return ciImage }
        guard var texture = ciImage.cgImage?.mt.newTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
        } catch {
            throw error
        }
        return applyCIImage(ciImage, with: texture)
    }
    
    func filtering(cgImage: CGImage) throws -> CGImage {
        if self.filters.isEmpty { return cgImage }
        guard var texture = cgImage.mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            return texture.mt.toCGImage() ?? cgImage
        } catch {
            throw error
        }
    }
    
    func filtering(image: C7Image) throws -> C7Image {
        if self.filters.isEmpty { return image }
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
        if self.filters.isEmpty { return texture }
        var sourceTexture: MTLTexture = texture
        // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
        // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
        var destTexture = BoxxIO.destTexture(bufferPixelFormat, width: sourceTexture.width, height: sourceTexture.height)
        do {
            for filter in filters {
                let resize = filter.resize(input: C7Size(width: texture.width, height: texture.height))
                if destTexture.width != resize.width || destTexture.height != resize.height {
                    destTexture = BoxxIO.destTexture(bufferPixelFormat, width: resize.width, height: resize.height)
                }
                sourceTexture = try Processed.IO(inTexture: sourceTexture, outTexture: destTexture, filter: filter)
            }
            return sourceTexture
        } catch {
            throw error
        }
    }
}

extension BoxxIO {
    
    public func filtering(texture: MTLTexture, complete: @escaping (Result<MTLTexture, Error>) -> Void) {
        var index__ = 0
        var destTexture = BoxxIO.destTexture(bufferPixelFormat, width: texture.width, height: texture.height)
        // 递归处理
        func recursion(filters: [C7FilterProtocol], index: Int, sourceTexture: MTLTexture) {
            let filter = filters[index]
            let resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
            if destTexture.width != resize.width || destTexture.height != resize.height {
                destTexture = BoxxIO.destTexture(bufferPixelFormat, width: resize.width, height: resize.height)
            }
            if filters.count == index + 1 {
                Processed.runAsynIO(inTexture: sourceTexture, outTexture: destTexture, filter: filter) { res in
                    switch res {
                    case .success(let t):
                        complete(.success(t))
                    case .failure(let error):
                        complete(.failure(error))
                    }
                }
            } else {
                Processed.runAsynIO(inTexture: sourceTexture, outTexture: destTexture, filter: filter) { res in
                    switch res {
                    case .success(let t):
                        index__ += 1
                        recursion(filters: filters, index: index__, sourceTexture: t)
                    case .failure(let error):
                        complete(.failure(error))
                    }
                }
            }
        }
        recursion(filters: filters, index: index__, sourceTexture: texture)
    }
}

// MARK: - private methods
extension BoxxIO {
    /// Create a texture for later storage according to the texture parameters.
    /// - Parameters:
    ///    - pixelformat: Indicates the pixelFormat, The format of the picture should be consistent with the data
    ///    - width: The texture width
    ///    - height: The texture height
    ///    - mipmapped: No mapping was required
    /// - Returns: New textures
    static func destTexture(_ pixelFormat: MTLPixelFormat = MTLPixelFormat.rgba8Unorm,
                             width: Int, height: Int,
                             mipmapped: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: mipmapped)
        descriptor.usage = [.shaderRead, .shaderWrite]
        #if targetEnvironment(macCatalyst)
        descriptor.storageMode = .managed
        #endif
        return Device.device().makeTexture(descriptor: descriptor)!
    }
    
    private func applyCIImage(_ ciImage: CIImage, with texture: MTLTexture) -> CIImage {
        ciImage.mt.renderImageToTexture(texture, context: Device.context())
        guard let ciImage_ = CIImage(mtlTexture: texture) else {
            return ciImage
        }
        if mirrored, #available(iOS 11.0, *) {
            // When the CIImage is created, it is mirrored and flipped upside down.
            // But upon inspecting the texture, it still renders the CIImage as expected.
            // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
            return ciImage_.oriented(.downMirrored)
        }
        return ciImage_
    }
    
    private func fixImageOrientation(texture: MTLTexture, base: C7Image) throws -> C7Image {
        guard let cgImage = texture.mt.toCGImage() else {
            throw C7CustomError.texture2Image
        }
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Fixed an issue with HEIC flipping after adding filter.
        return C7Image(cgImage: cgImage, scale: base.scale, orientation: base.imageOrientation)
        #elseif os(macOS)
        let fImage = cgImage.mt.toC7Image()
        let image = C7Image(size: fImage.size)
        image.lockFocus()
        if self.heic { image.mt.flip(horizontal: true, vertical: true) }
        fImage.draw(in: NSRect(origin: .zero, size: fImage.size))
        image.unlockFocus()
        return image
        #else
        return base
        #endif
    }
}
