//
//  HarbethIO.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//  https://github.com/yangKJ/Harbeth

import Foundation
import MetalKit
import CoreImage
import CoreMedia
import CoreVideo

@available(*, deprecated, message: "Typo. Use `HarbethIO` instead", renamed: "HarbethIO")
public typealias BoxxIO<Dest> = HarbethIO<Dest>

/// Quickly add filters to sources.
/// Support use `UIImage/NSImage, CGImage, CIImage, MTLTexture, CMSampleBuffer, CVPixelBuffer/CVImageBuffer`
///
/// For example:
///
///     let filter = C7Storyboard(ranks: 2)
///     let dest = HarbethIO.init(element: originImage, filter: filter)
///     ImageView.image = try? dest.output()
///
///     // Asynchronous add filters to sources.
///     dest.transmitOutput(success: { [weak self] image in
///         // do somthing..
///     })
///
@frozen public struct HarbethIO<Dest> : Destype {
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
    
    /// Do you need to create an output texture object?
    /// If you do not create a separate output texture, texture overlay may occur.
    public var createDestTexture: Bool = true
    
    /// Metal texture transmit output real time commit buffer.
    /// Fixed camera capture output CMSampleBuffer.
    public var transmitOutputRealTimeCommit: Bool = false {
        didSet {
            if transmitOutputRealTimeCommit {
                hasCoreImage = true
            }
        }
    }
    
    /// 烦死😡，中间加入CoreImage滤镜不能最后才渲染，考虑到性能最大化，这边分开处理。
    /// After adding the CoreImage filter in the middle, it can't be rendered until the end.
    /// Considering the maximization of performance, we will deal with it separately.
    private var hasCoreImage: Bool
    
    public init(element: Dest, filters: [C7FilterProtocol]) {
        self.element = element
        self.filters = filters
        self.hasCoreImage = filters.contains { $0 is CoreImageProtocol }
    }
    
    public func output() throws -> Dest {
        if self.filters.isEmpty {
            return element
        }
        switch element {
        case let ee as MTLTexture:
            return try filtering(texture: ee) as! Dest
        case let ee as C7Image:
            return try filtering(image: ee) as! Dest
        case let ee as CIImage:
            return try filtering(ciImage: ee) as! Dest
        case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
            return try filtering(cgImage: ee as! CGImage) as! Dest
        case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
            return try filtering(pixelBuffer: ee as! CVPixelBuffer) as! Dest
        case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
            return try filtering(sampleBuffer: ee as! CMSampleBuffer) as! Dest
        default:
            break
        }
        return element
    }
    
    /// Convert to texture and add filters.
    /// - Parameter complete: The conversion is complete.
    public func transmitOutput(complete: @escaping (Result<Dest, HarbethError>) -> Void) {
        if self.filters.isEmpty {
            complete(.success(element))
            return
        }
        switch element {
        case let ee as MTLTexture:
            filtering(texture: ee, complete: { complete($0.map { $0 as! Dest }) })
        case let ee as C7Image:
            filtering(image: ee, complete: { complete($0.map { $0 as! Dest }) })
        case let ee as CIImage:
            filtering(ciImage: ee, complete: { complete($0.map { $0 as! Dest }) })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
            filtering(cgImage: ee as! CGImage, complete: { complete($0.map { $0 as! Dest }) })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
            filtering(pixelBuffer: ee as! CVPixelBuffer, complete: { complete($0.map { $0 as! Dest }) })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
            filtering(sampleBuffer: ee as! CMSampleBuffer, complete: { complete($0.map { $0 as! Dest }) })
        default:
            complete(.success(element))
        }
    }
    
    /// Asynchronous convert to texture and add filters.
    /// - Parameters:
    ///   - texture: Input metal texture.
    ///   - complete: The conversion is complete.
    public func filtering(texture: MTLTexture, complete: @escaping (Result<MTLTexture, HarbethError>) -> Void) {
        if self.filters.isEmpty {
            complete(.success(texture))
            return
        }
        var commandBuffer: MTLCommandBuffer?
        if self.hasCoreImage == false {
            do {
                commandBuffer = try makeCommandBuffer()
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
                return
            }
        }
        var result: MTLTexture = texture
        var iterator = self.filters.makeIterator()
        // 递归处理
        func recursion(filter: C7FilterProtocol?, sourceTexture: MTLTexture) {
            guard let filter = filter else {
                if hasCoreImage {
                    complete(.success(result))
                } else {
                    commandBuffer?.asyncCommit { complete($0.map({ result })) }
                }
                return
            }
            runAsyncIO(with: sourceTexture, filter: filter, complete: { res in
                switch res {
                case .success(let t):
                    result = t
                    recursion(filter: iterator.next(), sourceTexture: result)
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            }, buffer: commandBuffer)
        }
        recursion(filter: iterator.next(), sourceTexture: result)
    }
}

// MARK: - filtering methods
extension HarbethIO {
    
    private func filtering(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        let inTexture = try TextureLoader.init(with: pixelBuffer).texture
        let texture = try filtering(texture: inTexture)
        pixelBuffer.c7.copyToPixelBuffer(with: texture)
        return pixelBuffer
    }
    
    private func filtering(sampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw HarbethError.CMSampleBufferToCVPixelBuffer
        }
        let p = try filtering(pixelBuffer: pixelBuffer)
        guard let buffer = p.c7.toCMSampleBuffer() else {
            throw HarbethError.CVPixelBufferToCMSampleBuffer
        }
        return buffer
    }
    
    private func filtering(ciImage: CIImage) throws -> CIImage {
        let inTexture = try TextureLoader.init(with: ciImage).texture
        let texture = try filtering(texture: inTexture)
        return try texture.c7.toCIImage(mirrored: mirrored)
    }
    
    private func filtering(cgImage: CGImage) throws -> CGImage {
        let inTexture = try TextureLoader.init(with: cgImage).texture
        let texture = try filtering(texture: inTexture)
        guard let cgImg = texture.c7.toCGImage() else {
            throw HarbethError.texture2Image
        }
        return cgImg
    }
    
    private func filtering(image: C7Image) throws -> C7Image {
        let inTexture = try TextureLoader.init(with: image).texture
        let texture = try filtering(texture: inTexture)
        return try texture.c7.fixImageOrientation(refImage: image)
    }
    
    private func filtering(texture: MTLTexture) throws -> MTLTexture {
        var inTexture: MTLTexture = texture
        if hasCoreImage {
            for filter in filters {
                inTexture = try textureIO(with: inTexture, filter: filter, for: nil)
            }
        } else {
            let commandBuffer = try makeCommandBuffer()
            for filter in filters {
                inTexture = try textureIO(with: inTexture, filter: filter, for: commandBuffer)
            }
            commandBuffer.commitAndWaitUntilCompleted()
        }
        return inTexture
    }
}

// MARK: - asynchronous filtering methods
extension HarbethIO {
    
    private func filtering(pixelBuffer: CVPixelBuffer, complete: @escaping (Result<CVPixelBuffer, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: pixelBuffer).texture
            filtering(texture: texture, complete: { res in
                let ress = res.map {
                    pixelBuffer.c7.copyToPixelBuffer(with: $0)
                    return pixelBuffer
                }
                complete(ress)
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
    
    private func filtering(sampleBuffer: CMSampleBuffer, complete: @escaping (Result<CMSampleBuffer, HarbethError>) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer((sampleBuffer)) else {
            complete(.failure(HarbethError.CMSampleBufferToCVPixelBuffer))
            return
        }
        filtering(pixelBuffer: pixelBuffer, complete: { res in
            switch res {
            case .success(let p):
                guard let buffer = p.c7.toCMSampleBuffer() else {
                    complete(.failure(HarbethError.CVPixelBufferToCMSampleBuffer))
                    return
                }
                complete(.success(buffer))
            case .failure(let error):
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        })
    }
    
    private func filtering(ciImage: CIImage, complete: @escaping (Result<CIImage, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: ciImage).texture
            filtering(texture: texture, complete: { res in
                switch res {
                case .success(let t):
                    do {
                        let result = try t.c7.toCIImage(mirrored: mirrored)
                        complete(.success(result))
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
    
    private func filtering(cgImage: CGImage, complete: @escaping (Result<CGImage, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: cgImage).texture
            filtering(texture: texture, complete: { res in
                switch res {
                case .success(let t):
                    guard let result = t.c7.toCGImage() else {
                        complete(.failure(HarbethError.texture2Image))
                        return
                    }
                    complete(.success(result))
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
    
    private func filtering(image: C7Image, complete: @escaping (Result<C7Image, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: image).texture
            filtering(texture: texture, complete: { res in
                switch res {
                case .success(let t):
                    do {
                        let result = try t.c7.fixImageOrientation(refImage: image)
                        complete(.success(result))
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
}

// MARK: - private methods
extension HarbethIO {
    
    private func createDestTexture(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        if self.createDestTexture == false {
            return sourceTexture
        }
        let params = filter.parameterDescription
        if !(params["needCreateDestTexture"] as? Bool ?? true) {
            // 纯色`C7SolidColor`和渐变色`C7ColorGradient`滤镜不需要创建新的输出纹理，直接使用输入纹理即可
            return sourceTexture
        }
        let resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
        // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
        return try TextureLoader.emptyTexture(width: resize.width, height: resize.height, options: [
            .texturePixelFormat: bufferPixelFormat
        ])
    }
    
    /// Do you need to create a new metal texture command buffer.
    /// - Parameter buffer: Old command buffer.
    /// - Returns: A command buffer.
    private func makeCommandBuffer(for buffer: MTLCommandBuffer? = nil) throws -> MTLCommandBuffer {
        if let commandBuffer = buffer {
            return commandBuffer
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        return commandBuffer
    }
    
    /// Create a new texture based on the filter content.
    /// Synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - texture: Input texture
    ///   - filter: It must be an object implementing C7FilterProtocol
    ///   - buffer: A valid MTLCommandBuffer to receive the encoded filter.
    /// - Returns: Output texture after processing
    private func textureIO(with texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer?) throws -> MTLTexture {
        let commandBuffer = try makeCommandBuffer(for: buffer)
        var destTexture = try createDestTexture(with: texture, filter: filter)
        let inputTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
        switch filter.modifier {
        case .coreimage(let name) where filter is CoreImageProtocol:
            let outputImage = try (filter as! CoreImageProtocol).outputCIImage(with: inputTexture, name: name)
            try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
        case .compute, .mps, .render:
            destTexture = try filter.applyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer)
        default:
            return texture
        }
        let outputTexture = try filter.combinationAfter(for: commandBuffer, input: destTexture, source: texture)
        if hasCoreImage {
            commandBuffer.commitAndWaitUntilCompleted()
        }
        return outputTexture
    }
    
    /// Whether to synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - texture: Input texture
    ///   - filter: It must be an object implementing C7FilterProtocol.
    ///   - complete: Add a block to be called when this command buffer has completed execution.
    ///   - buffer: A valid MTLCommandBuffer to receive the encoded filter.
    private func runAsyncIO(with texture: MTLTexture,
                            filter: C7FilterProtocol,
                            complete: @escaping (Result<MTLTexture, HarbethError>) -> Void,
                            buffer: MTLCommandBuffer?) {
        func combinationAfter(for buffer: MTLCommandBuffer, inputTexture: MTLTexture) {
            do {
                let finalTexture = try filter.combinationAfter(for: buffer, input: inputTexture, source: texture)
                if hasCoreImage {
                    buffer.asyncCommit { complete($0.map({ finalTexture })) }
                } else {
                    complete(.success(finalTexture))
                }
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        }
        do {
            let commandBuffer = try makeCommandBuffer(for: buffer)
            let destTexture = try createDestTexture(with: texture, filter: filter)
            let inputTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
            switch filter.modifier {
            case .coreimage(let name) where filter is CoreImageProtocol:
                let outputImage = try (filter as! CoreImageProtocol).outputCIImage(with: inputTexture, name: name)
                try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
                combinationAfter(for: commandBuffer, inputTexture: destTexture)
            case .compute, .mps, .render:
                filter.asyncApplyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer) { res in
                    switch res {
                    case .success(let outTexture):
                        combinationAfter(for: commandBuffer, inputTexture: outTexture)
                    case .failure(let err):
                        complete(.failure(err))
                    }
                }
            default:
                break
            }
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
}
