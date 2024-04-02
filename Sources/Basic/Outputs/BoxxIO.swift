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
/// Support use `UIImage/NSImage, CGImage, CIImage, MTLTexture, CMSampleBuffer, CVPixelBuffer/CVImageBuffer`
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
    
    public init(element: Dest, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }
    
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
    
    /// Convert to texture and add filters.
    /// - Parameters:
    ///   - texture: Input metal texture.
    ///   - complete: The conversion is complete.
    public func filtering(texture: MTLTexture, complete: @escaping (Result<MTLTexture, HarbethError>) -> Void) {
        if self.filters.isEmpty {
            complete(.success(texture))
            return
        }
        var result: MTLTexture = texture
        var iterator = self.filters.makeIterator()
        var commandBuffer: MTLCommandBuffer?
        if self.hasCoreImage == false {
            do {
                commandBuffer = try makeCommandBuffer()
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        }
        // 递归处理
        func recursion(filter: C7FilterProtocol?, sourceTexture: MTLTexture) {
            guard let filter = filter else {
                if hasCoreImage {
                    complete(.success(result))
                } else {
                    commandBuffer?.asyncCommit(texture: result, complete: complete)
                }
                return
            }
            runAsyncIO(with: sourceTexture, filter: filter, complete: { res in
                let ress = res.map {
                    result = $0
                    recursion(filter: iterator.next(), sourceTexture: result)
                    return $0
                }
                complete(ress)
            }, buffer: commandBuffer)
        }
        recursion(filter: iterator.next(), sourceTexture: texture)
    }
}

// MARK: - filtering methods
extension BoxxIO {
    
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
        return try fixImageOrientation(texture: texture, refImage: image)
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
extension BoxxIO {
    
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
                        let result = try fixImageOrientation(texture: t, refImage: image)
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
extension BoxxIO {
    
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
    
    private func fixImageOrientation(texture: MTLTexture, refImage: C7Image) throws -> C7Image {
        guard let cgImage = texture.c7.toCGImage() else {
            throw HarbethError.texture2Image
        }
        return cgImage.c7.drawing(refImage: refImage).c7.flattened()
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
        let destTexture = try createDestTexture(with: texture, filter: filter)
        switch filter.modifier {
        case .coreimage(let name):
            let outputImage = try filter.outputCIImage(with: texture, name: name)
            try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
            commandBuffer.commitAndWaitUntilCompleted()
            return destTexture
        case .compute, .mps, .render:
            let beiginTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
            let outputTexture = try filter.applyAtTexture(form: beiginTexture, to: destTexture, for: commandBuffer)
            let finalTexture = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: texture)
            if hasCoreImage {
                commandBuffer.commitAndWaitUntilCompleted()
            }
            return finalTexture
        default:
            return texture
        }
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
        do {
            let commandBuffer = try makeCommandBuffer(for: buffer)
            switch filter.modifier {
            case .coreimage(let name):
                let outputImage = try filter.outputCIImage(with: texture, name: name)
                //let finaTexture = try TextureLoader(with: outputImage).texture
                try outputImage.c7.renderCIImageToTexture(texture, commandBuffer: commandBuffer)
                commandBuffer.asyncCommit(texture: texture, complete: complete)
            case .compute, .mps, .render:
                let destTexture = try createDestTexture(with: texture, filter: filter)
                let inputTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
                asyncApplyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer, filter: filter) { res in
                    switch res {
                    case .success(let outTexture):
                        do {
                            let finalTexture = try filter.combinationAfter(for: commandBuffer, input: outTexture, source: texture)
                            if hasCoreImage {
                                commandBuffer.asyncCommit(texture: finalTexture, complete: complete)
                            } else {
                                complete(.success(finalTexture))
                            }
                        } catch {
                            complete(.failure(HarbethError.toHarbethError(error)))
                        }
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
    
    private func asyncApplyAtTexture(form texture: MTLTexture,
                                     to destTexture: MTLTexture,
                                     for buffer: MTLCommandBuffer,
                                     filter: C7FilterProtocol,
                                     complete: @escaping (Result<MTLTexture, HarbethError>) -> Void) {
        do {
            switch filter.modifier {
            case .compute(let kernel):
                var textures = [destTexture, texture]
                textures += filter.otherInputTextures
                filter.drawing(with: kernel, commandBuffer: buffer, textures: textures, complete: complete)
            case .render(let vertex, let fragment):
                let pipelineState = try Rendering.makeRenderPipelineState(with: vertex, fragment: fragment)
                Rendering.drawingProcess(pipelineState, commandBuffer: buffer, texture: texture, filter: filter)
                complete(.success(destTexture))
            case .mps where filter is MPSKernelProtocol:
                var textures = [destTexture, texture]
                textures += filter.otherInputTextures
                let finaTexture = try (filter as! MPSKernelProtocol).encode(commandBuffer: buffer, textures: textures)
                complete(.success(finaTexture))
            default:
                complete(.success(texture))
            }
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
}
