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
@frozen public struct HarbethIO<Dest> {
    public typealias Element = Dest
    public let element: Dest
    public let filters: [C7FilterProtocol]
    
    /// Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
    /// The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
    public var bufferPixelFormat: MTLPixelFormat = .bgra8Unorm {
        didSet { setupedBufferPixelFormat = true }
    }
    /// When the CIImage is created, it is mirrored and flipped upside down.
    /// But upon inspecting the texture, it still renders the CIImage as expected.
    /// Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
    public var mirrored: Bool = false
    /// Do you need to create an output texture object?
    /// If you do not create a separate output texture, texture overlay may occur.
    public var createDestTexture: Bool = true
    /// Metal texture transmit output real time commit buffer.
    /// Scale factor for intermediate textures (0.0-1.0), default is 1.0 (no scaling)
    public var scaleFactor: Float = 1.0
    /// Fixed camera capture output CMSampleBuffer.
    public var transmitOutputRealTimeCommit: Bool = false
    /// Enable double buffer optimization for metal filters
    /// When there are less than 4 filters, the traditional(singleBuffer) mode is better.
    public var enableDoubleBuffer: Bool = true
    
    private var setupedBufferPixelFormat = false
    private let identifier: String
    private let hasCoreImage: Bool
    private let hasAppleLogDecode: Bool
    
    private enum GroupStrategy {
        case batched, interleaved
    }
    
    public init(element: Dest, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }
    
    public init(element: Dest, filters: C7FilterProtocol...) {
        self.init(element: element, filters: filters)
    }
    
    public init(element: Dest, filters: [C7FilterProtocol]) {
        self.element = element
        self.identifier = UUID().uuidString
        self.filters = filters
        var hasCoreImage = false
        var hasAppleLogDecode = false
        for filter in filters {
            if !hasCoreImage && filter.modifier.isCoreImage {
                hasCoreImage = true
            }
            if !hasAppleLogDecode && filter is C7AppleLogDecode {
                hasAppleLogDecode = true
            }
            if hasCoreImage && hasAppleLogDecode {
                break
            }
        }
        self.hasCoreImage = hasCoreImage
        self.hasAppleLogDecode = hasAppleLogDecode
    }
    
    /// Add filters to sources synchronously. If it fails, it returns element.
    public func filtered() -> Dest {
        return (try? self.output()) ?? element
    }
    
    /// Add filters to sources asynchronously.
    /// - Returns: The result of adding filters to the sources asynchronously.
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
            return element
        }
    }
    
    /// Asynchronous quickly add filters to sources.
    /// - Parameter complete: The conversion is complete of adding filters to the sources asynchronously.
    public func transmitOutput(success: @escaping (Dest) -> Void, failed: ((HarbethError) -> Void)? = nil) {
        transmitOutput { result in
            switch result {
            case .success(let output):
                success(output)
            case .failure(let error):
                failed?(HarbethError.toHarbethError(error))
            }
        }
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
    public func filtering(texture: MTLTexture, complete: @escaping C7TextureResultBlock) {
        if self.filters.isEmpty {
            complete(.success(texture))
            return
        }
        Device.renderQueue.async {
            Device.renderSemaphore.wait()
            defer { Device.renderSemaphore.signal() }
            do {
                if hasCoreImage || transmitOutputRealTimeCommit {
                    let outputTexture = try filtering(texture: texture)
                    complete(.success(outputTexture))
                } else {
                    let commandBuffer = try makeCommandBuffer()
                    let outputTexture: MTLTexture
                    if enableDoubleBuffer && filters.count > 3 {
                        outputTexture = try doubleBuffering(input: texture, filters: filters, commandBuffer: commandBuffer)
                    } else {
                        outputTexture = try singleBuffer(input: texture, filters: filters, commandBuffer: commandBuffer)
                    }
                    commandBuffer.asyncCommit { result in
                        switch result {
                        case .success:
                            complete(.success(outputTexture))
                        case .failure(let error):
                            complete(.failure(HarbethError.toHarbethError(error)))
                        }
                    }
                }
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        }
    }
}

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
        switch groupStrategy {
        case .batched:
            return try processBatchedFilters(input: texture)
        case .interleaved:
            return try processInterleavedFilters(input: texture)
        }
    }
    
    private func processBatchedFilters(input: MTLTexture) throws -> MTLTexture {
        let filterGroups = groupFilters(by: { $0.modifier.isCoreImage })
        var outputTexture = input
        var currentCommandBuffer: MTLCommandBuffer? = nil
        
        for group in filterGroups {
            if group.first?.modifier.isCoreImage ?? false {
                if let commandBuffer = currentCommandBuffer {
                    commandBuffer.commitAndWaitUntilCompleted()
                    currentCommandBuffer = nil
                }
                guard var inputCIImage = outputTexture.c7.toCIImage() else {
                    continue
                }
                for filter in group.map({ $0 as! CoreImageProtocol }) {
                    inputCIImage = try filter.outputCIImage(with: inputCIImage)
                }
                let commandBuffer = try makeCommandBuffer(for: nil)
                let destTexture = try TextureLoader.makeTexture(at: inputCIImage.extent.size)
                try inputCIImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
                outputTexture = destTexture
                commandBuffer.commitAndWaitUntilCompleted()
            } else {
                if currentCommandBuffer == nil {
                    currentCommandBuffer = try makeCommandBuffer(for: nil)
                }
                if enableDoubleBuffer {
                    outputTexture = try doubleBuffering(input: outputTexture, filters: group, commandBuffer: currentCommandBuffer!)
                } else {
                    outputTexture = try singleBuffer(input: outputTexture, filters: group, commandBuffer: currentCommandBuffer!)
                }
            }
        }
        
        // Submit the last Metal command buffer.
        if let commandBuffer = currentCommandBuffer {
            commandBuffer.commitAndWaitUntilCompleted()
        }
        return outputTexture
    }
    
    private func processInterleavedFilters(input: MTLTexture) throws -> MTLTexture {
        var outputTexture = input
        var temporaryTextures: [MTLTexture] = []
        for filter in filters {
            let commandBuffer = try makeCommandBuffer(for: nil)
            let tempTexture = try textureIO(input: outputTexture, filter: filter, for: commandBuffer)
            if tempTexture !== outputTexture {
                temporaryTextures.append(tempTexture)
            }
            outputTexture = tempTexture
            commandBuffer.commitAndWaitUntilCompleted()
        }
        // Return temporary textures to the pool to exclude input and output textures.
        for texture in temporaryTextures where texture !== input && texture !== outputTexture {
            TextureLoader.returnTexture(toPool: texture)
        }
        return outputTexture
    }
}

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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
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

extension HarbethIO {
    
    private var groupStrategy: GroupStrategy {
        let filterGroups = groupFilters(by: { $0.modifier.isCoreImage })
        for group in filterGroups where group.count > 1 {
            return .batched
        }
        return .interleaved
    }
    
    private func groupFilters(by predicate: (C7FilterProtocol) -> Bool) -> [[C7FilterProtocol]] {
        var groups: [[C7FilterProtocol]] = []
        var currentGroup: [C7FilterProtocol] = []
        var currentType: Bool?
        for filter in filters {
            let filterType = predicate(filter)
            if currentType == nil || currentType == filterType {
                currentGroup.append(filter)
                currentType = filterType
            } else {
                groups.append(currentGroup)
                currentGroup = [filter]
                currentType = filterType
            }
        }
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        return groups
    }
    
    private func setupBufferPixelFormat(with sourceTexture: MTLTexture) -> MTLPixelFormat {
        if !setupedBufferPixelFormat {
            if hasAppleLogDecode {
                return .rgba16Float
            } else {
                return sourceTexture.pixelFormat
            }
        }
        return bufferPixelFormat
    }
    
    private func createDestTexture(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        if !createDestTexture || !(filter.parameterDescription["needCreateDestTexture"] as? Bool ?? true) {
            return sourceTexture
        }
        let targetPixelFormat = setupBufferPixelFormat(with: sourceTexture)
        var resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        // Apply scale factor if set
        let scaleFactor_ = min(max(0.0, scaleFactor), 1.0)
        if scaleFactor_ != 1.0 {
            let scaledWidth = Int(Float(resize.width) * scaleFactor_)
            let scaledHeight = Int(Float(resize.height) * scaleFactor_)
            resize = C7Size(width: max(1, scaledWidth), height: max(1, scaledHeight))
        }
        
        if Device.enablePerformanceMonitor {
            PerformanceMonitor.shared.recordTextureCreation(identifier, created: false)
        }
        // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
        // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
        let texture = try TextureLoader.makeTexture(width: resize.width, height: resize.height, options: [
            .texturePixelFormat: targetPixelFormat
        ])
        if Device.enablePerformanceMonitor {
            PerformanceMonitor.shared.recordTextureCreation(identifier, created: true)
        }
        return texture
    }
    
    /// Do you need to create a new metal texture command buffer.
    private func makeCommandBuffer(for buffer: MTLCommandBuffer? = nil) throws -> MTLCommandBuffer {
        if let commandBuffer = buffer {
            return commandBuffer
        }
        if Device.enablePerformanceMonitor {
            PerformanceMonitor.shared.recordCommandBufferCreation(identifier, created: false)
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        if Device.enablePerformanceMonitor {
            PerformanceMonitor.shared.recordCommandBufferCreation(identifier, created: true)
        }
        return commandBuffer
    }
    
    /// Create a new texture based on the filter content.
    private func textureIO(input texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        let destTexture = try createDestTexture(with: texture, filter: filter)
        let inputTexture = try filter.combinationBegin(for: buffer, source: texture, dest: destTexture)
        let outputTexture: MTLTexture
        if case .coreimage = filter.modifier {
            let outputImage = try (filter as! CoreImageProtocol).outputCIImage(with: inputTexture)
            try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: buffer)
            outputTexture = destTexture
        } else {
            outputTexture = try filter.apply(form: inputTexture, to: destTexture, for: buffer, complete: nil)
        }
        return try filter.combinationAfter(for: buffer, input: outputTexture, source: texture)
    }
    
    private func singleBuffer(input: MTLTexture, filters: [C7FilterProtocol], commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        var temporaryTextures: [MTLTexture] = []
        let outputTexture = try filters.reduce(input) { texture, filter in
            let tempTexture = try textureIO(input: texture, filter: filter, for: commandBuffer)
            if tempTexture !== input {
                temporaryTextures.append(tempTexture)
            }
            return tempTexture
        }
        for texture in temporaryTextures where texture !== input && texture !== outputTexture {
            TextureLoader.returnTexture(toPool: texture)
        }
        return outputTexture
    }
    
    /// Use double buffer technology to handle filter chains.
    private func doubleBuffering(input: MTLTexture, filters: [C7FilterProtocol], commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        let width = input.width
        let height = input.height
        let pixelFormat = input.pixelFormat
        
        Shared.shared.prewarmTexturePool(resolutions: [(width: width, height: height, pixelFormat: pixelFormat)], count: 2)
        
        let textureA = try TextureLoader.makeOptimizedTexture(width: width, height: height, pixelFormat: pixelFormat)
        let textureB = try TextureLoader.makeOptimizedTexture(width: width, height: height, pixelFormat: pixelFormat)
        
        var currentInput = input
        var currentOutput = textureA
        
        for (index, filter) in filters.enumerated() {
            if let _ = filter as? C7CombinationBase {
                currentInput = try textureIO(input: currentInput, filter: filter, for: commandBuffer)
            } else {
                let preparedInput = try filter.combinationBegin(for: commandBuffer, source: currentInput, dest: currentOutput)
                let outputTexture = try filter.apply(form: preparedInput, to: currentOutput, for: commandBuffer, complete: nil)
                currentInput = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: currentInput)
                if index < filters.count - 1 {
                    currentOutput = currentOutput === textureA ? textureB : textureA
                }
            }
        }
        
        TextureLoader.returnTexture(toPool: textureA)
        TextureLoader.returnTexture(toPool: textureB)
        
        return currentInput
    }
}
