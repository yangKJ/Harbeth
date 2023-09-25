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
    
    /// Metal texture transmit output real time commit buffer.
    /// Fixed camera capture output CMSampleBuffer.
    public var transmitOutputRealTimeCommit: Bool = false {
        didSet {
            if transmitOutputRealTimeCommit {
                hasCoreImage = transmitOutputRealTimeCommit
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
        let inTexture = try TextureLoader.init(with: pixelBuffer).texture
        let texture = try filtering(texture: inTexture)
        pixelBuffer.c7.copyToPixelBuffer(with: texture)
        return pixelBuffer
    }
    
    private func filtering(sampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw CustomError.CMSampleBufferToCVPixelBuffer
        }
        let p = try filtering(pixelBuffer: pixelBuffer)
        guard let buffer = p.c7.toCMSampleBuffer() else {
            throw CustomError.CVPixelBufferToCMSampleBuffer
        }
        return buffer
    }
    
    private func filtering(ciImage: CIImage) throws -> CIImage {
        let inTexture = try TextureLoader.init(with: ciImage).texture
        let texture = try filtering(texture: inTexture)
        return try applyCIImage(with: texture)
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
        if hasCoreImage {
            for filter in filters {
                inTexture = try textureIO(with: inTexture, filter: filter)
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
    
    private func filtering(pixelBuffer: CVPixelBuffer, success: @escaping (CVPixelBuffer) -> Void, failed: @escaping (CustomError) -> Void) {
        func setupTexture(_ texture: MTLTexture) {
            filtering(texture: texture, success: { t in
                pixelBuffer.c7.copyToPixelBuffer(with: t)
                success(pixelBuffer)
            }, failed: failed)
        }
        do {
            let texture = try TextureLoader(with: pixelBuffer).texture
            setupTexture(texture)
        } catch {
            failed(CustomError.toCustomError(error))
        }
    }
    
    private func filtering(sampleBuffer: CMSampleBuffer, success: @escaping (CMSampleBuffer) -> Void, failed: @escaping (CustomError) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer((sampleBuffer)) else {
            failed(CustomError.CMSampleBufferToCVPixelBuffer)
            return
        }
        filtering(pixelBuffer: pixelBuffer, success: { p in
            guard let buffer = p.c7.toCMSampleBuffer() else {
                failed(CustomError.CVPixelBufferToCMSampleBuffer)
                return
            }
            success(buffer)
        }, failed: failed)
    }
    
    private func filtering(ciImage: CIImage, success: @escaping (CIImage) -> Void, failed: @escaping (CustomError) -> Void) {
        func setupTexture(_ texture: MTLTexture) {
            filtering(texture: texture, success: { t in
                do {
                    let ciImage_ = try applyCIImage(with: t)
                    success(ciImage_)
                } catch {
                    failed(CustomError.toCustomError(error))
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
    
    private func filtering(texture: MTLTexture, success: @escaping (MTLTexture) -> Void, failed: @escaping (CustomError) -> Void) {
        var result: MTLTexture = texture
        var iterator = filters.makeIterator()
        var commandBuffer: MTLCommandBuffer?
        if hasCoreImage == false {
            do {
                commandBuffer = try makeCommandBuffer()
            } catch {
                failed(CustomError.toCustomError(error))
            }
        }
        // 递归处理
        func recursion(filter: C7FilterProtocol?, sourceTexture: MTLTexture) {
            guard let filter = filter else {
                if hasCoreImage {
                    success(result)
                } else {
                    commandBuffer?.asyncCommit(texture: result) { res in
                        switch res {
                        case .success(let t):
                            success(t)
                        case .failure(let error):
                            failed(error)
                        }
                    }
                }
                return
            }
            runAsyncIO(with: sourceTexture, filter: filter, complete: { res in
                switch res {
                case .success(let t):
                    result = t
                    recursion(filter: iterator.next(), sourceTexture: result)
                case .failure(let error):
                    failed(error)
                }
            }, buffer: commandBuffer)
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
        return try TextureLoader.emptyTexture(width: resize.width, height: resize.height, options: [
            .texturePixelFormat: bufferPixelFormat
        ])
    }
    
    private func applyCIImage(with texture: MTLTexture) throws -> CIImage {
        guard let ciImage = texture.c7.toCIImage() else {
            throw CustomError.texture2CIImage
        }
        if self.mirrored, #available(iOS 11.0, macOS 10.13, *) {
            // When the CIImage is created, it is mirrored and flipped upside down.
            // But upon inspecting the texture, it still renders the CIImage as expected.
            // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
            return ciImage.oriented(.downMirrored)
        }
        return ciImage
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
    /// Do you need to create a new metal texture command buffer.
    /// - Parameter buffer: Old command buffer.
    /// - Returns: A command buffer.
    private func makeCommandBuffer(for buffer: MTLCommandBuffer? = nil) throws -> MTLCommandBuffer {
        if let commandBuffer = buffer {
            return commandBuffer
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
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
    private func textureIO(with texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer? = nil) throws -> MTLTexture {
        let commandBuffer = try makeCommandBuffer(for: buffer)
        switch filter.modifier {
        case .coreimage(let name):
            let destTexture = try createDestTexture(with: texture, filter: filter)
            let outputImage = try filter.outputCIImage(with: texture, name: name)
            try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
            return destTexture
        case .compute, .mps, .render:
            let destTexture = try createDestTexture(with: texture, filter: filter)
            let finaTexture: MTLTexture
            if let filter = filter as? CombinationProtocol {
                let beiginTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
                let outputTexture = try filter.applyAtTexture(form: beiginTexture, to: destTexture, for: commandBuffer)
                finaTexture = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: texture)
            } else {
                finaTexture = try filter.applyAtTexture(form: texture, to: destTexture, for: commandBuffer)
            }
            if hasCoreImage {
                commandBuffer.commitAndWaitUntilCompleted()
            }
            return finaTexture
        default:
            break
        }
        return texture
    }
    
    /// Whether to synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - texture: Input texture
    ///   - filter: It must be an object implementing C7FilterProtocol.
    ///   - complete: Add a block to be called when this command buffer has completed execution.
    ///   - buffer: A valid MTLCommandBuffer to receive the encoded filter.
    private func runAsyncIO(with texture: MTLTexture,
                            filter: C7FilterProtocol,
                            complete: @escaping (Result<MTLTexture, CustomError>) -> Void,
                            buffer: MTLCommandBuffer? = nil) {
        do {
            let commandBuffer = try makeCommandBuffer(for: buffer)
            switch filter.modifier {
            case .coreimage(let name):
                let outputImage = try filter.outputCIImage(with: texture, name: name)
                //let finaTexture = try TextureLoader(with: outputImage).texture
                outputImage.c7.asyncRenderCIImageToTexture(texture, commandBuffer: commandBuffer, complete: complete)
            case .compute, .mps, .render:
                let destTexture = try createDestTexture(with: texture, filter: filter)
                let inputTexture: MTLTexture
                if let filter = filter as? CombinationProtocol {
                    inputTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
                } else {
                    inputTexture = texture
                }
                asyncApplyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer, filter: filter) { res in
                    switch res {
                    case .success(let outputTexture):
                        var finaTexture: MTLTexture = outputTexture
                        if let filter = filter as? CombinationProtocol {
                            do {
                                finaTexture = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: texture)
                            } catch {
                                complete(.failure(CustomError.toCustomError(error)))
                            }
                        }
                        if hasCoreImage {
                            commandBuffer.asyncCommit(texture: finaTexture, complete: complete)
                        } else {
                            complete(.success(finaTexture))
                        }
                    case .failure(let err):
                        complete(.failure(err))
                    }
                }
            default:
                break
            }
        } catch {
            complete(.failure(CustomError.toCustomError(error)))
        }
    }
    
    private func asyncApplyAtTexture(form texture: MTLTexture,
                                     to destTexture: MTLTexture,
                                     for buffer: MTLCommandBuffer,
                                     filter: C7FilterProtocol,
                                     complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
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
            complete(.failure(CustomError.toCustomError(error)))
        }
    }
}
