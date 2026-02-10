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
    /// Fixed camera capture output CMSampleBuffer.
    public var transmitOutputRealTimeCommit: Bool = false
    /// Enable performance monitoring
    public var enablePerformanceMonitor: Bool = false
    /// Memory limit for texture processing in MB
    public var memoryLimitMB: Int = 512
    /// Scale factor for intermediate textures (0.0-1.0), default is 1.0 (no scaling)
    public var scaleFactor: Float = 1.0 {
        didSet { scaleFactor = min(max(0.0, scaleFactor), 1.0) }
    }
    
    private var hasCoreImage: Bool
    private var setupedBufferPixelFormat = false
    private let identifier: String
    private let renderQueue = DispatchQueue(
        label: "com.harbeth.run.async.render",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .workItem
    )
    
    private enum CoreImageStrategy {
        case none, batched, interleaved
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
        self.hasCoreImage = filters.contains {
            if case .coreimage = $0.modifier { return true }
            return false
        }
        self.filters = filters//Self.optimizeFilters(filters)
    }
    
    /// Add filters to sources synchronously. If it fails, it returns element.
    public func filtered() -> Dest {
        return (try? self.output()) ?? element
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
        switch coreImageStrategy {
        case .none:
            processPureMetalFilters(texture: texture, complete: complete)
        case .batched:
            if transmitOutputRealTimeCommit {
                processInterleavedFilters(texture: texture, complete: complete)
            } else {
                processBatchedFilters(texture: texture, complete: complete)
            }
        case .interleaved:
            processInterleavedFilters(texture: texture, complete: complete)
        }
    }
}

extension HarbethIO {
    /// Set the buffer pixel format
    /// - Parameter pixelFormat: Pixel format to use
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withBufferPixelFormat(_ pixelFormat: MTLPixelFormat) -> Self {
        self.bufferPixelFormat = pixelFormat
        return self
    }
    
    /// Set whether to mirror the output
    /// - Parameter mirrored: Whether to mirror
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withMirrored(_ mirrored: Bool) -> Self {
        self.mirrored = mirrored
        return self
    }
    
    /// Set whether to create a destination texture
    /// - Parameter create: Whether to create
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withCreateDestTexture(_ create: Bool) -> Self {
        self.createDestTexture = create
        return self
    }
    
    /// Set whether to transmit output real time commit
    /// - Parameter commit: Whether to commit in real time
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withTransmitOutputRealTimeCommit(_ commit: Bool) -> Self {
        self.transmitOutputRealTimeCommit = commit
        return self
    }
    
    /// Set whether to enable performance monitoring
    /// - Parameter enable: Whether to enable
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withEnablePerformanceMonitor(_ enable: Bool) -> Self {
        self.enablePerformanceMonitor = enable
        return self
    }
    
    /// Set the memory limit for texture processing
    /// - Parameter limit: Memory limit in MB
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withMemoryLimitMB(_ limit: Int) -> Self {
        self.memoryLimitMB = limit
        return self
    }
    
    /// Set the scale factor for intermediate textures
    /// - Parameter scaleFactor: Scale factor (0.0-1.0)
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func withScaleFactor(_ scaleFactor: Float) -> Self {
        self.scaleFactor = scaleFactor
        return self
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
        switch coreImageStrategy {
        case .none:
            return try processPureMetalFilters(input: texture)
        case .batched:
            return try processBatchedFilters(input: texture)
        case .interleaved:
            return try processInterleavedFilters(input: texture)
        }
    }
    
    private func processPureMetalFilters(input: MTLTexture) throws -> MTLTexture {
        let commandBuffer = try makeCommandBuffer(for: nil)
        var temporaryTextures: [MTLTexture] = []
        let outputTexture = try filters.reduce(input) { texture, filter in
            let tempTexture = try textureIO(input: texture, filter: filter, for: commandBuffer)
            if tempTexture !== input {
                temporaryTextures.append(tempTexture)
            }
            return tempTexture
        }
        commandBuffer.commitAndWaitUntilCompleted()
        for texture in temporaryTextures where texture !== input && texture !== outputTexture {
            TextureLoader.returnTexture(toPool: texture)
        }
        return outputTexture
    }
    
    private func processBatchedFilters(input: MTLTexture) throws -> MTLTexture {
        let filterGroups = groupConsecutiveFilters(by: { $0.modifier.isCoreImage })
        var outputTexture = input
        var temporaryTextures: [MTLTexture] = []
        for group in filterGroups {
            if group.first?.modifier.isCoreImage ?? false {
                guard var inputCIImage = outputTexture.c7.toCIImage() else {
                    continue
                }
                for filter in group.map({ $0 as! CoreImageProtocol }) {
                    inputCIImage = try filter.outputCIImage(with: inputCIImage)
                }
                let commandBuffer = try makeCommandBuffer(for: nil)
                let destTexture = try TextureLoader.makeTexture(at: inputCIImage.extent.size)
                temporaryTextures.append(destTexture)
                try inputCIImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
                outputTexture = destTexture
                commandBuffer.commitAndWaitUntilCompleted()
            } else {
                let commandBuffer = try makeCommandBuffer(for: nil)
                outputTexture = try group.reduce(outputTexture) { texture, filter in
                    let tempTexture = try textureIO(input: texture, filter: filter, for: commandBuffer)
                    if tempTexture !== texture {
                        temporaryTextures.append(tempTexture)
                    }
                    return tempTexture
                }
                commandBuffer.commitAndWaitUntilCompleted()
            }
        }
        for texture in temporaryTextures where texture !== input && texture !== outputTexture {
            TextureLoader.returnTexture(toPool: texture)
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
    
    private func processPureMetalFilters(texture: MTLTexture, complete: @escaping C7TextureResultBlock) {
        do {
            let commandBuffer = try makeCommandBuffer()
            try runAsyncIO(input: texture, index: 0, commandBuffer: commandBuffer, temporaryTextures: [])
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
        func runAsyncIO(input: MTLTexture, index: Int, commandBuffer: MTLCommandBuffer, temporaryTextures: [MTLTexture]) throws {
            if index >= filters.count {
                commandBuffer.asyncCommit { result in
                    switch result {
                    case .success:
                        for tempTexture in temporaryTextures where tempTexture !== texture && tempTexture !== input {
                            TextureLoader.returnTexture(toPool: tempTexture)
                        }
                        complete(.success(input))
                    case .failure(let error):
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                }
                return
            }
            let filter = filters[index]
            switch filter.modifier {
            case .compute, .mps, .render:
                let dest = try createDestTexture(with: input, filter: filter)
                var newTemporaryTextures = temporaryTextures
                if dest !== input {
                    newTemporaryTextures.append(dest)
                }
                let preparedInput = try filter.combinationBegin(for: commandBuffer, source: input, dest: dest)
                try filter.applyAtTexture(form: preparedInput, to: dest, for: commandBuffer) { result in
                    do {
                        switch result {
                        case .success(let t):
                            let output = try filter.combinationAfter(for: commandBuffer, input: t, source: input)
                            if output !== dest {
                                newTemporaryTextures.append(output)
                            }
                            try runAsyncIO(input: output, index: index+1, commandBuffer: commandBuffer, temporaryTextures: newTemporaryTextures)
                        case .failure(let error):
                            throw HarbethError.toHarbethError(error)
                        }
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                }
            case .blit:
                let dest = try createDestTexture(with: input, filter: filter)
                var newTemporaryTextures = temporaryTextures
                if dest !== input {
                    newTemporaryTextures.append(dest)
                }
                let preparedInput = try filter.combinationBegin(for: commandBuffer, source: input, dest: dest)
                let output = try filter.applyAtTexture(form: preparedInput, to: dest, for: commandBuffer)
                let finalOutput = try filter.combinationAfter(for: commandBuffer, input: output, source: input)
                if finalOutput !== output {
                    newTemporaryTextures.append(finalOutput)
                }
                try runAsyncIO(input: finalOutput, index: index+1, commandBuffer: commandBuffer, temporaryTextures: newTemporaryTextures)
            case .coreimage:
                try runAsyncIO(input: input, index: index+1, commandBuffer: commandBuffer, temporaryTextures: temporaryTextures)
            }
        }
    }
    
    private func processBatchedFilters(texture: MTLTexture, complete: @escaping C7TextureResultBlock) {
        let filterGroups = groupConsecutiveFilters(by: { $0.modifier.isCoreImage })
        func processGroup(at index: Int, inputTexture: MTLTexture, temporaryTextures: [MTLTexture]) {
            guard index < filterGroups.count else {
                for tempTexture in temporaryTextures where tempTexture !== texture && tempTexture !== inputTexture {
                    TextureLoader.returnTexture(toPool: tempTexture)
                }
                complete(.success(inputTexture))
                return
            }
            let group = filterGroups[index]
            if group.first is CoreImageProtocol {
                self.renderQueue.async {
                    do {
                        guard var inputCIImage = inputTexture.c7.toCIImage() else {
                            return
                        }
                        for filter in group.map({ $0 as! CoreImageProtocol }) {
                            inputCIImage = try filter.outputCIImage(with: inputCIImage)
                        }
                        let commandBuffer = try self.makeCommandBuffer()
                        let destTexture = try TextureLoader.makeTexture(at: inputCIImage.extent.size, options: [
                            .texturePixelFormat: self.rgba8UnormTexture ? .rgba8Unorm : self.bufferPixelFormat
                        ])
                        var newTemporaryTextures = temporaryTextures
                        if destTexture !== inputTexture {
                            newTemporaryTextures.append(destTexture)
                        }
                        try inputCIImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
                        commandBuffer.asyncCommit { result in
                            switch result {
                            case .success:
                                processGroup(at: index + 1, inputTexture: destTexture, temporaryTextures: newTemporaryTextures)
                            case .failure(let error):
                                complete(.failure(HarbethError.toHarbethError(error)))
                            }
                        }
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                }
            } else {
                do {
                    let commandBuffer = try self.makeCommandBuffer()
                    var newTemporaryTextures = temporaryTextures
                    let outputTexture = try group.reduce(inputTexture) { tex, filter in
                        let dest = try self.createDestTexture(with: tex, filter: filter)
                        if dest !== tex {
                            newTemporaryTextures.append(dest)
                        }
                        let prepared = try filter.combinationBegin(for: commandBuffer, source: tex, dest: dest)
                        let out = try filter.applyAtTexture(form: prepared, to: dest, for: commandBuffer)
                        let finalOutput = try filter.combinationAfter(for: commandBuffer, input: out, source: tex)
                        if finalOutput !== out {
                            newTemporaryTextures.append(finalOutput)
                        }
                        return finalOutput
                    }
                    commandBuffer.asyncCommit { result in
                        switch result {
                        case .success:
                            processGroup(at: index + 1, inputTexture: outputTexture, temporaryTextures: newTemporaryTextures)
                        case .failure(let error):
                            complete(.failure(HarbethError.toHarbethError(error)))
                        }
                    }
                } catch {
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            }
        }
        processGroup(at: 0, inputTexture: texture, temporaryTextures: [])
    }
    
    private func processInterleavedFilters(texture: MTLTexture, complete: @escaping C7TextureResultBlock) {
        var iterator = self.filters.makeIterator()
        func recursion(filter: C7FilterProtocol?, sourceTexture: MTLTexture, temporaryTextures: [MTLTexture]) {
            guard let filter = filter else {
                for tempTexture in temporaryTextures where tempTexture !== texture && tempTexture !== sourceTexture {
                    TextureLoader.returnTexture(toPool: tempTexture)
                }
                complete(.success(sourceTexture))
                return
            }
            runAsyncIO(with: sourceTexture, filter: filter, complete: {
                switch $0 {
                case .success(let t):
                    var newTemporaryTextures = temporaryTextures
                    if t !== sourceTexture {
                        newTemporaryTextures.append(t)
                    }
                    recursion(filter: iterator.next(), sourceTexture: t, temporaryTextures: newTemporaryTextures)
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        }
        recursion(filter: iterator.next(), sourceTexture: texture, temporaryTextures: [])
    }
}

extension HarbethIO {
    private static func optimizeFilters(_ filters: [C7FilterProtocol]) -> [C7FilterProtocol] {
        guard filters.count > 1 else {
            return filters
        }
        var optimized: [C7FilterProtocol] = []
        var currentGroup: [C7FilterProtocol] = []
        for filter in filters {
            if case .compute = filter.modifier, currentGroup.count >= 1, currentGroup.allSatisfy({
                if case .compute = $0.modifier {
                    return true
                }
                return false
            }) {
                currentGroup.append(filter)
            } else {
                if !currentGroup.isEmpty {
                    if currentGroup.count == 1 {
                        optimized.append(currentGroup[0])
                    } else {
                        optimized.append(contentsOf: currentGroup)
                    }
                    currentGroup = []
                }
                currentGroup.append(filter)
            }
        }
        if !currentGroup.isEmpty {
            if currentGroup.count == 1 {
                optimized.append(currentGroup[0])
            } else {
                optimized.append(contentsOf: currentGroup)
            }
        }
        return optimized
    }
    
    private var coreImageStrategy: CoreImageStrategy {
        if !hasCoreImage { return .none }
        let filterGroups = groupConsecutiveFilters(by: { $0.modifier.isCoreImage })
        let coreImageGroups = filterGroups.filter { $0.first?.modifier.isCoreImage == true }
        for group in coreImageGroups where group.count > 1 {
            return .batched
        }
        return .interleaved
    }
    
    private func groupConsecutiveFilters(by predicate: (C7FilterProtocol) -> Bool) -> [[C7FilterProtocol]] {
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
    
    /// The default setting for MTLPixelFormat is rgba8Unorm.
    private var rgba8UnormTexture: Bool {
        switch element {
        case _ as MTLTexture:
            return true
        case _ as C7Image:
            return true
        case _ as CIImage:
            return true
        case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
            return true
        case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
            return false
        case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
            return false
        default:
            return false
        }
    }
    
    private func createDestTexture(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        if !createDestTexture || !(filter.parameterDescription["needCreateDestTexture"] as? Bool ?? true) {
            return sourceTexture
        }
        var targetPixelFormat = bufferPixelFormat
        if !setupedBufferPixelFormat && rgba8UnormTexture {
            targetPixelFormat = .rgba8Unorm
        }
        let resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        
        // Apply scale factor if set
        let scaledWidth = Int(Float(resize.width) * scaleFactor)
        let scaledHeight = Int(Float(resize.height) * scaleFactor)
        let finalSize = C7Size(width: max(1, scaledWidth), height: max(1, scaledHeight))
        
        if enablePerformanceMonitor {
            PerformanceMonitor.shared.recordTextureCreation(identifier, created: false)
        }
        // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
        // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
        let texture = try TextureLoader.makeTexture(width: finalSize.width, height: finalSize.height, options: [
            .texturePixelFormat: targetPixelFormat
        ])
        if enablePerformanceMonitor {
            PerformanceMonitor.shared.recordTextureCreation(identifier, created: true)
        }
        return texture
    }
    
    /// Do you need to create a new metal texture command buffer.
    /// - Parameter buffer: Old command buffer.
    /// - Returns: A command buffer.
    private func makeCommandBuffer(for buffer: MTLCommandBuffer? = nil) throws -> MTLCommandBuffer {
        if let commandBuffer = buffer {
            return commandBuffer
        }
        if enablePerformanceMonitor {
            PerformanceMonitor.shared.recordCommandBufferCreation(identifier, created: false)
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        if enablePerformanceMonitor {
            PerformanceMonitor.shared.recordCommandBufferCreation(identifier, created: true)
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
    private func textureIO(input texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        let destTexture = try createDestTexture(with: texture, filter: filter)
        let inputTexture = try filter.combinationBegin(for: buffer, source: texture, dest: destTexture)
        let outputTexture: MTLTexture
        if case .coreimage = filter.modifier {
            let outputImage = try (filter as! CoreImageProtocol).outputCIImage(with: inputTexture)
            try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: buffer)
            outputTexture = destTexture
        } else {
            outputTexture = try filter.applyAtTexture(form: inputTexture, to: destTexture, for: buffer)
        }
        return try filter.combinationAfter(for: buffer, input: outputTexture, source: texture)
    }
    
    /// Whether to synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - texture: Input texture
    ///   - filter: It must be an object implementing C7FilterProtocol.
    ///   - complete: Add a block to be called when this command buffer has completed execution.
    private func runAsyncIO(with texture: MTLTexture, filter: C7FilterProtocol, complete: @escaping C7TextureResultBlock) {
        do {
            let commandBuffer = try makeCommandBuffer(for: nil)
            let destTexture = try createDestTexture(with: texture, filter: filter)
            let inputTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
            switch filter.modifier {
            case .coreimage:
                self.renderQueue.async {
                    do {
                        let outputImage = try (filter as! CoreImageProtocol).outputCIImage(with: inputTexture)
                        try outputImage.c7.renderCIImageToTexture(destTexture, commandBuffer: commandBuffer)
                        let finalTexture = try filter.combinationAfter(for: commandBuffer, input: destTexture, source: texture)
                        commandBuffer.asyncCommit { complete($0.map({ finalTexture })) }
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                }
            case .compute, .mps, .render:
                try filter.applyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer) { res in
                    switch res {
                    case .success(let destTexture):
                        do {
                            let finalTexture = try filter.combinationAfter(for: commandBuffer, input: destTexture, source: texture)
                            commandBuffer.asyncCommit { complete($0.map({ finalTexture })) }
                        } catch {
                            complete(.failure(HarbethError.toHarbethError(error)))
                        }
                    case .failure(let err):
                        complete(.failure(err))
                    }
                }
            case .blit:
                do {
                    let output = try filter.applyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer)
                    let finalTexture = try filter.combinationAfter(for: commandBuffer, input: output, source: texture)
                    commandBuffer.asyncCommit { complete($0.map({ finalTexture })) }
                } catch {
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            }
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
}
