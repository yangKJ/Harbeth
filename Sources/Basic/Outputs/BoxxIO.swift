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
    
    /// Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
    /// The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
    public var bufferPixelFormat: MTLPixelFormat = .bgra8Unorm
    
    /// When the CIImage is created, it is mirrored and flipped upside down.
    /// But upon inspecting the texture, it still renders the CIImage as expected.
    /// Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
    public var mirrored: Bool = false
    
    #if os(macOS)
    /// Fixed an issue with HEIC flipping after adding filter.
    /// If drawing a HEIC, we need to make context flipped.
    public var heic: Bool = false
    #endif
    
    /// Do you need to create an output texture object?
    /// Such as solid color and gradient filters do not need to create an output texture.
    public var createDestTexture: Bool = true
    
    public init(element: Dest, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }
    
    public init(element: Dest, filters: [C7FilterProtocol]) {
        self.element = element
        self.filters = filters
    }
    
    public func output() throws -> Dest {
        if self.filters.isEmpty {
            return element
        }
        do {
            switch element {
            case let e as MTLTexture:
                return try filtering(texture: e) as! Dest
            case let e as C7Image:
                return try filtering(image: e) as! Dest
            case let e as CIImage:
                return try filtering(ciImage: e) as! Dest
            case let e where CFGetTypeID(e as CFTypeRef) == CGImage.typeID:
                return try filtering(cgImage: e as! CGImage) as! Dest
            case let e where CFGetTypeID(e as CFTypeRef) == CVPixelBufferGetTypeID():
                return try filtering(pixelBuffer: e as! CVPixelBuffer) as! Dest
            case let e where CFGetTypeID(e as CFTypeRef) == CMSampleBufferGetTypeID():
                return try filtering(sampleBuffer: e as! CMSampleBuffer) as! Dest
            default:
                break
            }
        } catch {
            throw error
        }
        return element
    }
    
    public func transmitOutput(success: @escaping (Dest) -> Void, failed: @escaping (CustomError) -> Void) {
        if self.filters.isEmpty {
            success(element)
            return
        }
        if let element = element as? MTLTexture {
            filtering(texture: element) { res in
                switch res {
                case .success(let t):
                    success(t as! Dest)
                case .failure(let err):
                    failed(err)
                }
            }
        } else if let element = element as? C7Image {
            guard let texture = element.mt.toTexture() else {
                failed(CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    do {
                        let image = try fixImageOrientation(texture: t, base: element)
                        success(image as! Dest)
                    } catch {
                        failed(CustomError.toCustomError(error))
                    }
                case .failure(let err):
                    failed(err)
                }
            }
        } else if let element = element as? CIImage {
            guard let texture = element.cgImage?.mt.newTexture() else {
                failed(CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    self.asyncApplyCIImage(element, with: t) { res_ in
                        switch res_ {
                        case .success(let ciImage):
                            success(ciImage as! Dest)
                        case .failure(let err):
                            failed(err)
                        }
                    }
                case .failure(let err):
                    failed(err)
                }
            }
        } else if CFGetTypeID(element as CFTypeRef) == CGImage.typeID {
            guard let texture = (element as! CGImage).mt.toTexture() else {
                failed(CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    guard let cgImage = t.mt.toCGImage() else {
                        failed(CustomError.texture2Image)
                        return
                    }
                    success(cgImage as! Dest)
                case .failure(let err):
                    failed(err)
                }
            }
        } else if CFGetTypeID(element as CFTypeRef) == CVPixelBufferGetTypeID() {
            guard let texture = (element as! CVPixelBuffer).mt.toMTLTexture() else {
                failed(CustomError.source2Texture)
                return
            }
            let pixelBuffer = element as! CVPixelBuffer
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    pixelBuffer.mt.copyToPixelBuffer(with: t)
                    success(pixelBuffer as! Dest)
                case .failure(let err):
                    failed(err)
                }
            }
        } else if CFGetTypeID(element as CFTypeRef) == CMSampleBufferGetTypeID() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer((element as! CMSampleBuffer)),
                  let texture = pixelBuffer.mt.toMTLTexture() else {
                failed(CustomError.source2Texture)
                return
            }
            filtering(texture: texture) { res in
                switch res {
                case .success(let t):
                    pixelBuffer.mt.copyToPixelBuffer(with: t)
                    guard let buffer = pixelBuffer.mt.toCMSampleBuffer() else {
                        failed(CustomError.CVPixelBufferToCMSampleBuffer)
                        return
                    }
                    success(buffer as! Dest)
                case .failure(let err):
                    failed(err)
                }
            }
        }
    }
}

// MARK: - filtering methods
extension BoxxIO {
    
    func filtering(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        guard var texture = pixelBuffer.mt.toMTLTexture() else {
            throw CustomError.source2Texture
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
        guard var pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw CustomError.source2Texture
        }
        do {
            pixelBuffer = try filtering(pixelBuffer: pixelBuffer)
            guard let buffer = pixelBuffer.mt.toCMSampleBuffer() else {
                throw CustomError.CVPixelBufferToCMSampleBuffer
            }
            return buffer
        } catch {
            throw error
        }
    }
    
    func filtering(ciImage: CIImage) throws -> CIImage {
        guard var texture = ciImage.cgImage?.mt.newTexture() else {
            throw CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
        } catch {
            throw error
        }
        return applyCIImage(ciImage, with: texture)
    }
    
    func filtering(cgImage: CGImage) throws -> CGImage {
        guard var texture = cgImage.mt.toTexture() else {
            throw CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            guard let cgImg = texture.mt.toCGImage() else {
                throw CustomError.texture2Image
            }
            return cgImg
        } catch {
            throw error
        }
    }
    
    func filtering(image: C7Image) throws -> C7Image {
        guard var texture = image.mt.toTexture() else {
            throw CustomError.source2Texture
        }
        do {
            texture = try filtering(texture: texture)
            return try fixImageOrientation(texture: texture, base: image)
        } catch {
            throw error
        }
    }
    
    func filtering(texture: MTLTexture) throws -> MTLTexture {
        var sourceTexture: MTLTexture = texture
        do {
            for filter in filters {
                let destTexture = createDestTexture(with: sourceTexture, filter: filter)
                sourceTexture = try Processed.IO(inTexture: sourceTexture, outTexture: destTexture, filter: filter)
            }
            return sourceTexture
        } catch {
            throw error
        }
    }
}

extension BoxxIO {
    
    public func filtering(texture: MTLTexture, complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        var result: MTLTexture = texture
        var iterator = filters.makeIterator()
        // 递归处理
        func recursion(filter: C7FilterProtocol?, sourceTexture: MTLTexture) {
            guard let filter = filter else {
                complete(.success(result))
                return
            }
            Processed.runAsynIO(inTexture: sourceTexture, outTexture: result, filter: filter) { res in
                switch res {
                case .success(let t):
                    result = t
                    recursion(filter: iterator.next(), sourceTexture: texture)
                case .failure(let error):
                    complete(.failure(error))
                }
            }
        }
        recursion(filter: iterator.next(), sourceTexture: texture)
    }
}

// MARK: - private methods
extension BoxxIO {
    private func createDestTexture(with sourceTexture: MTLTexture, filter: C7FilterProtocol) -> MTLTexture {
        if self.createDestTexture == false {
            // 纯色`C7SolidColor`和渐变色`C7ColorGradient`滤镜不需要创建新的输出纹理，直接使用输入纹理即可
            return sourceTexture
        }
        let resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
        // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
        return MTLTextureCompatible_.destTexture(bufferPixelFormat, width: resize.width, height: resize.height)
    }
    
    private func applyCIImage(_ ciImage: CIImage, with texture: MTLTexture) -> CIImage {
        try? ciImage.mt.renderImageToTexture(texture, context: Device.context())
        guard let ciImage_ = CIImage(mtlTexture: texture) else {
            return ciImage
        }
        if self.mirrored, #available(iOS 11.0, macOS 10.13, *) {
            // When the CIImage is created, it is mirrored and flipped upside down.
            // But upon inspecting the texture, it still renders the CIImage as expected.
            // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
            return ciImage_.oriented(.downMirrored)
        }
        return ciImage_
    }
    
    private func asyncApplyCIImage(_ ciImage: CIImage, with texture: MTLTexture, complete: @escaping (Result<CIImage, CustomError>) -> Void) {
        ciImage.mt.writeCIImageAtTexture(texture, complete: { res in
            switch res {
            case .success(let texture):
                guard let ciImage_ = CIImage(mtlTexture: texture) else {
                    complete(.failure(CustomError.texture2CIImage))
                    return
                }
                if self.mirrored, #available(iOS 11.0, macOS 10.13, *) {
                    complete(.success(ciImage_.oriented(.downMirrored)))
                    return
                }
                complete(.success(ciImage_))
            case .failure(let error):
                complete(.failure(error))
            }
        }, context: Device.context())
    }
    
    private func fixImageOrientation(texture: MTLTexture, base: C7Image) throws -> C7Image {
        guard let cgImage = texture.mt.toCGImage() else {
            throw CustomError.texture2Image
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
