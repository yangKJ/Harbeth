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
        return element
    }
    
    /// Convert to texture and add filters.
    /// - Parameters:
    ///   - frequently: If frequentlied commit buffer, there will be a jamming asynchronously, you need to set the attribute to ture.
    ///   - texture: Input metal texture.
    ///   - complete: The conversion is complete.
    public func transmitOutput(success: @escaping (Dest) -> Void, failed: @escaping (CustomError) -> Void) {
        if self.filters.isEmpty {
            success(element)
            return
        }
        switch element {
        case let e as MTLTexture:
            filtering(texture: e, success: { success($0 as! Dest) }, failed: failed)
        case let e as C7Image:
            filtering(image: e, success: { success($0 as! Dest) }, failed: failed)
        case let e as CIImage:
            filtering(ciImage: e, success: { success($0 as! Dest) }, failed: failed)
        case let e where CFGetTypeID(e as CFTypeRef) == CGImage.typeID:
            filtering(cgImage: e as! CGImage, success: { success($0 as! Dest) }, failed: failed)
        case let e where CFGetTypeID(e as CFTypeRef) == CVPixelBufferGetTypeID():
            filtering(pixelBuffer: e as! CVPixelBuffer, success: { success($0 as! Dest) }, failed: failed)
        case let e where CFGetTypeID(e as CFTypeRef) == CMSampleBufferGetTypeID():
            filtering(sampleBuffer: e as! CMSampleBuffer, success: { success($0 as! Dest) }, failed: failed)
        default:
            success(element)
        }
    }
    
    /// Convert to texture and add filters.
    /// - Parameters:
    ///   - texture: Input metal texture.
    ///   - complete: The conversion is complete.
    public func filtering(texture: MTLTexture, complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        if self.filters.isEmpty {
            complete(.success(texture))
            return
        }
        filtering(texture: texture, success: { t in
            complete(.success(t))
        }, failed: { err in
            complete(.failure(err))
        })
    }
}

// MARK: - filtering methods
extension BoxxIO {
    
    private func filtering(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        guard let texture = pixelBuffer.c7.toMTLTexture() else {
            throw CustomError.source2Texture
        }
        let t = try filtering(texture: texture)
        pixelBuffer.c7.copyToPixelBuffer(with: t)
        return pixelBuffer
    }
    
    private func filtering(sampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw CustomError.source2Texture
        }
        let pixelBuffer_ = try filtering(pixelBuffer: pixelBuffer)
        guard let buffer = pixelBuffer_.c7.toCMSampleBuffer() else {
            throw CustomError.CVPixelBufferToCMSampleBuffer
        }
        return buffer
    }
    
    private func filtering(ciImage: CIImage) throws -> CIImage {
        let inTexture = try TextureLoader.init(with: ciImage).texture
        let texture = try filtering(texture: inTexture)
        return applyCIImage(ciImage, with: texture)
    }
    
    private func filtering(cgImage: CGImage) throws -> CGImage {
        let inTexture = try TextureLoader.init(with: cgImage).texture
        let texture = try filtering(texture: inTexture)
        guard let cgImg = texture.c7.toCGImage() else {
            throw CustomError.texture2Image
        }
        return cgImg
    }
    
    private func filtering(image: C7Image) throws -> C7Image {
        let inTexture = try TextureLoader.init(with: image).texture
        let texture = try filtering(texture: inTexture)
        return try fixImageOrientation(texture: texture, base: image)
    }
    
    private func filtering(texture: MTLTexture) throws -> MTLTexture {
        var inTexture: MTLTexture = texture
        for filter in filters {
            let destTexture = try createDestTexture(with: inTexture, filter: filter)
            inTexture = try Processed.IO(inTexture: inTexture, outTexture: destTexture, filter: filter)
        }
        return inTexture
    }
}

// MARK: - asynchronous filtering methods
extension BoxxIO {
    
    private func filtering(pixelBuffer: CVPixelBuffer, success: @escaping (CVPixelBuffer) -> Void, failed: @escaping (CustomError) -> Void) {
        guard let texture = pixelBuffer.c7.toMTLTexture() else {
            failed(CustomError.source2Texture)
            return
        }
        filtering(texture: texture, success: { t in
            pixelBuffer.c7.copyToPixelBuffer(with: t)
            success(pixelBuffer)
        }, failed: failed)
    }
    
    private func filtering(sampleBuffer: CMSampleBuffer, success: @escaping (CMSampleBuffer) -> Void, failed: @escaping (CustomError) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer((sampleBuffer)),
              let texture = pixelBuffer.c7.toMTLTexture() else {
            failed(CustomError.source2Texture)
            return
        }
        filtering(texture: texture, success: { t in
            pixelBuffer.c7.copyToPixelBuffer(with: t)
            guard let buffer = pixelBuffer.c7.toCMSampleBuffer() else {
                failed(CustomError.CVPixelBufferToCMSampleBuffer)
                return
            }
            success(buffer)
        }, failed: failed)
    }
    
    private func filtering(ciImage: CIImage, success: @escaping (CIImage) -> Void, failed: @escaping (CustomError) -> Void) {
        func setupTexture(_ texture: MTLTexture) {
            filtering(texture: texture, success: { t in
                self.asyncApplyCIImage(ciImage, with: t) { res in
                    switch res {
                    case .success(let ciImage):
                        success(ciImage)
                    case .failure(let err):
                        failed(err)
                    }
                }
            }, failed: failed)
        }
        do {
            let texture = try TextureLoader(with: ciImage).texture
            setupTexture(texture)
        } catch {
            failed(CustomError.toCustomError(error))
        }
    }
    
    private func filtering(cgImage: CGImage, success: @escaping (CGImage) -> Void, failed: @escaping (CustomError) -> Void) {
        func setupTexture(_ texture: MTLTexture) {
            filtering(texture: texture, success: { t in
                guard let cgImage = t.c7.toCGImage() else {
                    failed(CustomError.texture2Image)
                    return
                }
                success(cgImage)
            }, failed: failed)
        }
        do {
            let texture = try TextureLoader(with: cgImage).texture
            setupTexture(texture)
        } catch {
            failed(CustomError.toCustomError(error))
        }
    }
    
    private func filtering(image: C7Image, success: @escaping (C7Image) -> Void, failed: @escaping (CustomError) -> Void) {
        func setupTexture(_ texture: MTLTexture) {
            filtering(texture: texture, success: { t in
                do {
                    let image_ = try fixImageOrientation(texture: t, base: image)
                    success(image_)
                } catch {
                    failed(CustomError.toCustomError(error))
                }
            }, failed: failed)
        }
        do {
            let texture = try TextureLoader(with: image).texture
            setupTexture(texture)
        } catch {
            failed(CustomError.toCustomError(error))
        }
    }
    
    /// Convert to texture and add filters.
    /// - Parameters:
    ///   - texture: Input metal texture.
    ///   - success: Successful callback.
    ///   - failed: Failed callback.
    private func filtering(texture: MTLTexture, success: @escaping (MTLTexture) -> Void, failed: @escaping (CustomError) -> Void) {
        var result: MTLTexture = texture
        var iterator = filters.makeIterator()
        // 递归处理
        func recursion(filter: C7FilterProtocol?, sourceTexture: MTLTexture) {
            guard let filter = filter else {
                success(result)
                return
            }
            do {
                let destTexture = try createDestTexture(with: texture, filter: filter)
                Processed.runAsyncIO(intexture: sourceTexture, outTexture: destTexture, filter: filter) { res in
                    switch res {
                    case .success(let t):
                        result = t
                        recursion(filter: iterator.next(), sourceTexture: result)
                    case .failure(let error):
                        failed(error)
                    }
                }
            } catch {
                failed(CustomError.toCustomError(error))
            }
        }
        recursion(filter: iterator.next(), sourceTexture: texture)
    }
}

// MARK: - private methods
extension BoxxIO {
    
    private func createDestTexture(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        if self.createDestTexture == false {
            // 纯色`C7SolidColor`和渐变色`C7ColorGradient`滤镜不需要创建新的输出纹理，直接使用输入纹理即可
            return sourceTexture
        }
        let resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
        // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
        let texturior = Texturior(width: resize.width, height: resize.height, options: [
            .texturePixelFormat: bufferPixelFormat
        ])
        guard let destTexture = texturior.texture else {
            throw CustomError.makeTexture
        }
        return destTexture
    }
    
    private func applyCIImage(_ ciImage: CIImage, with texture: MTLTexture) -> CIImage {
        guard let texture_ = try? ciImage.c7.renderCIImageToTexture(texture),
              let ciImage_ = CIImage(mtlTexture: texture_) else {
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
        ciImage.c7.asyncRenderCIImageToTexture(texture, complete: { res in
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
        })
    }
    
    private func fixImageOrientation(texture: MTLTexture, base: C7Image) throws -> C7Image {
        guard let cgImage = texture.c7.toCGImage() else {
            throw CustomError.texture2Image
        }
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Fixed an issue with HEIC flipping after adding filter.
        return C7Image(cgImage: cgImage, scale: base.scale, orientation: base.imageOrientation)
        #elseif os(macOS)
        let fImage = cgImage.c7.toC7Image()
        let image = C7Image(size: fImage.size)
        image.lockFocus()
        if self.heic { image.c7.flip(horizontal: true, vertical: true) }
        fImage.draw(in: NSRect(origin: .zero, size: fImage.size))
        image.unlockFocus()
        return image
        #else
        return base
        #endif
    }
}

extension BoxxIO {
    
    // TODO: - 全部异步处理，异步生成纹理，中间处理纹理，最后异步提交绘制
    private func textureIO(with texture: MTLTexture, filter: C7FilterProtocol, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        switch filter.modifier {
        case .coreimage(let name):
            let outputImage = try filter.outputCIImage(with: texture, name: name)
            let options: [MTKTextureLoader.Option: Any] = [
                .sharedContext: Device.context(colorSpace: Device.colorSpace()),
            ]
            return try TextureLoader(with: outputImage, options: options).texture
        case .compute, .mps, .render:
            let destTexture = try createDestTexture(with: texture, filter: filter)
            return try filter.combinationIO(in: texture, to: destTexture, commandBuffer: commandBuffer)
        default:
            break
        }
        return texture
    }
}
