//
//  HarbethIO.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//  https://github.com/yangKJ/Harbeth

import Foundation
import MetalKit
import CoreMedia
import CoreVideo

@available(*, deprecated, message: "Typo. Use `HarbethIO` instead", renamed: "HarbethIO")
public typealias BoxxIO<Dest> = HarbethIO<Dest>

/// Quickly add filters to sources.
/// Support use `UIImage/NSImage, CGImage, MTLTexture, CMSampleBuffer, CVPixelBuffer/CVImageBuffer`.
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
    
    /// Host-side frame sources often use `kCVPixelFormatType_32BGRA`.
    /// Keep the pixel format aligned with the source to avoid color channel issues.
    public var bufferPixelFormat: MTLPixelFormat = .bgra8Unorm {
        didSet { setupedBufferPixelFormat = true }
    }
    /// Do you need to create an output texture object?
    /// If you do not create a separate output texture, texture overlay may occur.
    public var createDestTexture: Bool = true
    /// Whether to schedule the command buffer as soon as GPU execution is arranged,
    /// instead of waiting for full completion before continuing host-side flow.
    /// Recommended for low-latency frame processing paths.
    public var transmitOutputRealTimeCommit: Bool = false
    /// Enable double buffer optimization for metal filters
    /// When there are less than 4 filters, the traditional(singleBuffer) mode is better.
    public var enableDoubleBuffer: Bool = true
    /// Stable render intent for planning and diagnostics.
    public var renderProfile: RenderProfile = .stablePreview
    
    /// The identifier of the HarbethIO instance.
    public let identifier: String
    
    private var setupedBufferPixelFormat = false
    
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
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.beginMonitoring(identifier)
        }
        defer { Shared.shared.performanceMonitor?.endMonitoring(identifier) }
        switch element {
        case let ee as MTLTexture:
            return try filtering(texture: ee) as! Dest
        case let ee as C7Image:
            return try filtering(image: ee) as! Dest
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
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.beginMonitoring(identifier)
        }
        switch element {
        case let ee as MTLTexture:
            filtering(texture: ee, complete: {
                complete($0.map { $0 as! Dest })
                Shared.shared.performanceMonitor?.endMonitoring(self.identifier)
            })
        case let ee as C7Image:
            filtering(image: ee, complete: {
                complete($0.map { $0 as! Dest })
                Shared.shared.performanceMonitor?.endMonitoring(self.identifier)
            })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
            filtering(cgImage: ee as! CGImage, complete: {
                complete($0.map { $0 as! Dest })
                Shared.shared.performanceMonitor?.endMonitoring(self.identifier)
            })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
            filtering(pixelBuffer: ee as! CVPixelBuffer, complete: {
                complete($0.map { $0 as! Dest })
                Shared.shared.performanceMonitor?.endMonitoring(self.identifier)
            })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
            filtering(sampleBuffer: ee as! CMSampleBuffer, complete: {
                complete($0.map { $0 as! Dest })
                Shared.shared.performanceMonitor?.endMonitoring(self.identifier)
            })
        default:
            complete(.success(element))
            Shared.shared.performanceMonitor?.endMonitoring(self.identifier)
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
        let plan = makeRenderPlan(input: texture)
        prepareTextureLifecycle(for: plan, inputPixelFormat: texture.pixelFormat)
        let operation = BlockOperation {
            do {
                // Real-time mode: wait until scheduled, not completed
                if self.transmitOutputRealTimeCommit {
                    let commandBuffer = try self.makeCommandBuffer()
                    var outputTexture: MTLTexture
                    var texturesToEnqueue: [MTLTexture] = []
                    
                    if self.shouldUseDoubleBuffer(input: texture, plan: plan, minimumFilterCount: 4) {
                        outputTexture = try self.doubleBuffering(input: texture, plan: plan, commandBuffer: commandBuffer)
                    } else {
                        let result = try self.singleBuffer(input: texture, plan: plan, commandBuffer: commandBuffer)
                        outputTexture = result.0
                        texturesToEnqueue = result.1
                    }
                    
                    // Ensure textures are returned after GPU completion
                    if !texturesToEnqueue.isEmpty {
                        commandBuffer.addCompletedHandler { _ in
                            Shared.shared.defaultTexturePool.enqueueTexturesSync(texturesToEnqueue)
                        }
                    }
                    
                    // Real-time commit: wait until scheduled, not completed
                    commandBuffer.realTimeCommit(identifier: self.identifier) {
                        complete(.success(outputTexture))
                    }
                    
                    // Return command buffer in background
                    DispatchQueue.global().async {
                        commandBuffer.waitUntilCompleted()
                        Shared.shared.returnCommandBuffer(commandBuffer)
                    }
                } else {
                    // Normal async mode
                    let commandBuffer = try self.makeCommandBuffer()
                    var outputTexture: MTLTexture
                    var texturesToEnqueue: [MTLTexture] = []
                    
                    if self.shouldUseDoubleBuffer(input: texture, plan: plan, minimumFilterCount: 4) {
                        outputTexture = try self.doubleBuffering(input: texture, plan: plan, commandBuffer: commandBuffer)
                    } else {
                        let result = try self.singleBuffer(input: texture, plan: plan, commandBuffer: commandBuffer)
                        outputTexture = result.0
                        texturesToEnqueue = result.1
                    }
                    
                    commandBuffer.asyncCommit(identifier: self.identifier) { result in
                        switch result {
                        case .success:
                            Shared.shared.defaultTexturePool.enqueueTexturesSync(texturesToEnqueue)
                            Shared.shared.returnCommandBuffer(commandBuffer)
                            complete(.success(outputTexture))
                        case .failure(let error):
                            Shared.shared.returnCommandBuffer(commandBuffer)
                            complete(.failure(HarbethError.toHarbethError(error)))
                        }
                    }
                }
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        }
        Shared.shared.renderOperationQueue.addOperation(operation)
    }
}

struct ManagedTextureResult {
    let texture: MTLTexture
    let lease: TextureLease?
}

private struct ManagedTextureStage {
    let texture: MTLTexture
    let producedLease: TextureLease?
}

extension HarbethIO {
    
    func filtering(texture: MTLTexture) throws -> MTLTexture {
        let plan = makeRenderPlan(input: texture)
        switch groupStrategy(for: plan) {
        case .batched:
            return try processBatchedFilters(input: texture, plan: plan)
        case .interleaved:
            return try processInterleavedFilters(input: texture, plan: plan)
        }
    }
    
    private func processBatchedFilters(input: MTLTexture, plan: RenderPlan) throws -> MTLTexture {
        prepareTextureLifecycle(for: plan, inputPixelFormat: input.pixelFormat)
        let commandBuffer = try makeCommandBuffer(for: nil)
        let outputTexture: MTLTexture
        var texturesToEnqueue: [MTLTexture] = []
        if shouldUseDoubleBuffer(input: input, plan: plan, minimumFilterCount: 1) {
            outputTexture = try doubleBuffering(input: input, plan: plan, commandBuffer: commandBuffer)
        } else {
            let result = try singleBuffer(input: input, plan: plan, commandBuffer: commandBuffer)
            outputTexture = result.0
            texturesToEnqueue = result.1
        }
        commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
        Shared.shared.defaultTexturePool.enqueueTexturesSync(texturesToEnqueue)
        Shared.shared.returnCommandBuffer(commandBuffer)
        return outputTexture
    }
    
    private func processInterleavedFilters(input: MTLTexture, plan: RenderPlan) throws -> MTLTexture {
        prepareTextureLifecycle(for: plan, inputPixelFormat: input.pixelFormat)
        var outputTexture = input
        for node in plan.graph.nodes {
            guard let filter = node.filter else { continue }
            let commandBuffer = try makeCommandBuffer(for: nil)
            outputTexture = try textureIO(input: outputTexture, filter: filter, for: commandBuffer)
            commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
            Shared.shared.returnCommandBuffer(commandBuffer)
        }
        return outputTexture
    }
}

extension HarbethIO {
    
    func makeRenderPlan(input texture: MTLTexture) -> RenderPlan {
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: texture.width, height: texture.height),
            profile: renderProfile,
            compilationSource: .filtersPrimitive
        )
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
            let diagnostics = plan.diagnostics
            Shared.shared.performanceMonitor?.recordRenderOptimizationPlan(identifier, plan: diagnostics.optimizationPlan)
            if diagnostics.outputContract.requiresAlphaConversion {
                Shared.shared.performanceMonitor?.recordAlphaConversion(identifier, contract: diagnostics.outputContract.alpha)
            }
            if diagnostics.outputContract.requiresColorSpaceConversion {
                Shared.shared.performanceMonitor?.recordColorConversion(identifier, contract: diagnostics.outputContract.colorSpace)
            }
        }
        return plan
    }

    private func prepareTextureLifecycle(for plan: RenderPlan, inputPixelFormat: MTLPixelFormat) {
        let reservations = plan.diagnostics.optimizationPlan.prewarmReservations
        guard reservations.isEmpty == false else { return }
        Shared.shared.prewarmTexturePool(
            reservations: reservations,
            fallbackPixelFormat: inputPixelFormat,
            defaultCount: 1
        )
    }

    private func groupStrategy(for plan: RenderPlan) -> GroupStrategy {
        return plan.graph.nodes.count > 1 ? .batched : .interleaved
    }
    
    private func setupBufferPixelFormat(with sourceTexture: MTLTexture) -> MTLPixelFormat {
        if !setupedBufferPixelFormat {
            return sourceTexture.pixelFormat
        }
        return bufferPixelFormat
    }
    
    private func createDestTexture(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        if !createDestTexture || !(filter.parameterDescription["needCreateDestTexture"] as? Bool ?? true) {
            return sourceTexture
        }
        let targetPixelFormat = setupBufferPixelFormat(with: sourceTexture)
        var resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        
        // Calculate target size considering device limits
        let (deviceMaxWidth, deviceMaxHeight) = Device.makeTexture2DMaxSize(width: resize.width, height: resize.height)
        resize = C7Size(width: deviceMaxWidth, height: deviceMaxHeight)
        
        // Host-side frame sources often use `kCVPixelFormatType_32BGRA`.
        // Keep the output pixel format aligned with the source to avoid channel mismatch.
        let texture = try TextureLoader.makeTexture(width: resize.width, height: resize.height, options: [
            .texturePixelFormat: targetPixelFormat
        ], identifier: identifier)
        if Shared.shared.enablePerformanceMonitor {
            if sourceTexture.pixelFormat != targetPixelFormat {
                Shared.shared.performanceMonitor?.recordPixelFormatConversion(
                    identifier,
                    from: sourceTexture.pixelFormat,
                    to: targetPixelFormat
                )
            }
            // Record memory allocation
            let bytesPerPixel = 4 // RGBA8
            let memoryBytes = resize.width * resize.height * bytesPerPixel
            Shared.shared.performanceMonitor?.recordMemoryAllocation(identifier, bytes: memoryBytes, source: "Texture")
        }
        return texture
    }

    private func createDestTextureLease(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> TextureLease? {
        guard createDestTexture, (filter.parameterDescription["needCreateDestTexture"] as? Bool ?? true) else {
            return nil
        }
        let targetPixelFormat = setupBufferPixelFormat(with: sourceTexture)
        var resize = filter.resize(input: C7Size(width: sourceTexture.width, height: sourceTexture.height))
        let (deviceMaxWidth, deviceMaxHeight) = Device.makeTexture2DMaxSize(width: resize.width, height: resize.height)
        resize = C7Size(width: deviceMaxWidth, height: deviceMaxHeight)
        let lease = try TextureLoader.makeTextureLease(width: resize.width, height: resize.height, options: [
            .texturePixelFormat: targetPixelFormat
        ], identifier: identifier)
        if Shared.shared.enablePerformanceMonitor {
            if sourceTexture.pixelFormat != targetPixelFormat {
                Shared.shared.performanceMonitor?.recordPixelFormatConversion(
                    identifier,
                    from: sourceTexture.pixelFormat,
                    to: targetPixelFormat
                )
            }
            let bytesPerPixel = 4
            let memoryBytes = resize.width * resize.height * bytesPerPixel
            Shared.shared.performanceMonitor?.recordMemoryAllocation(identifier, bytes: memoryBytes, source: "TextureLease")
        }
        return lease
    }
    
    /// Do you need to create a new metal texture command buffer.
    private func makeCommandBuffer(for buffer: MTLCommandBuffer? = nil) throws -> MTLCommandBuffer {
        if let commandBuffer = buffer {
            return commandBuffer
        }
        guard let commandBuffer = Shared.shared.getCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        return commandBuffer
    }
    
    /// Create a new texture based on the filter content.
    private func textureIO(input texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        let destTexture = try createDestTexture(with: texture, filter: filter)
        let inputTexture = try filter.combinationBegin(for: buffer, source: texture, dest: destTexture)
        let outputTexture = try filter.apply(form: inputTexture, to: destTexture, for: buffer, complete: nil)
        return try filter.combinationAfter(for: buffer, input: outputTexture, source: texture)
    }

    private func textureIOManaged(input texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer) throws -> ManagedTextureStage {
        let destLease = try createDestTextureLease(with: texture, filter: filter)
        let destTexture = destLease?.texture ?? texture
        let inputTexture = try filter.combinationBegin(for: buffer, source: texture, dest: destTexture)
        let outputTexture = try filter.apply(form: inputTexture, to: destTexture, for: buffer, complete: nil)
        let finalTexture = try filter.combinationAfter(for: buffer, input: outputTexture, source: texture)
        return ManagedTextureStage(texture: finalTexture, producedLease: destLease)
    }
    
    private func singleBuffer(input: MTLTexture, plan: RenderPlan, commandBuffer: MTLCommandBuffer) throws -> (MTLTexture, [MTLTexture]) {
        var currentTexture = input
        var producedTextures: [MTLTexture] = []
        
        for node in plan.graph.nodes {
            guard let filter = node.filter else { continue }
            let next = try textureIO(input: currentTexture, filter: filter, for: commandBuffer)
            producedTextures.append(next)
            currentTexture = next
        }
        
        let finalTexture = currentTexture
        
        let texturesToEnqueue = producedTextures.filter { $0 !== input && $0 !== finalTexture }
        
        return (finalTexture, texturesToEnqueue)
    }
    

    private func shouldUseDoubleBuffer(input: MTLTexture, plan: RenderPlan, minimumFilterCount: Int) -> Bool {
        let filters = plan.graph.nodes.compactMap(\.filter)
        guard enableDoubleBuffer, filters.count >= minimumFilterCount else {
            return false
        }
        guard plan.containsBoundary == false else {
            return false
        }
        var inputSize = C7Size(width: input.width, height: input.height)
        for filter in filters {
            let outputSize = filter.resize(input: inputSize)
            if outputSize.width != inputSize.width || outputSize.height != inputSize.height {
                return false
            }
            inputSize = outputSize
        }
        return true
    }

    /// Use double buffer technology to handle filter chains.
    private func doubleBuffering(input: MTLTexture, plan: RenderPlan, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        let filters = plan.graph.nodes.compactMap(\.filter)
        let width = input.width
        let height = input.height
        let pixelFormat = input.pixelFormat
        
        Shared.shared.prewarmTexturePool(resolutions: [(width: width, height: height, pixelFormat: pixelFormat)], count: 2)
        let textureA = try TextureLoader.makeTexture(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ], identifier: identifier)
        let textureB = try TextureLoader.makeTexture(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ], identifier: identifier)
        
        var currentInput = input
        var currentOutput = textureA
        
        for (index, filter) in filters.enumerated() {
            if let filter = filter as? C7CombinationBase {
                filter.identifier = identifier
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
        
        // Double-buffer textures must not be returned to the pool before the GPU finishes using them.
        // Otherwise, subsequent render passes can dequeue and overwrite textures still in-flight.
        let finalTexture = currentInput
        let shouldEnqueueA = finalTexture !== textureA
        let shouldEnqueueB = finalTexture !== textureB
        commandBuffer.addCompletedHandler { _ in
            if shouldEnqueueA { Shared.shared.defaultTexturePool.enqueueTextureSync(textureA) }
            if shouldEnqueueB { Shared.shared.defaultTexturePool.enqueueTextureSync(textureB) }
        }
        
        return finalTexture
    }

    func makeEffectiveFilters(inputSize: C7Size, derivative: ImageDerivativeSpec) -> [C7FilterProtocol] {
        let baseOutputSize = filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        let targetOutputSize = derivative.resolvedOutputSize(for: baseOutputSize)
        guard targetOutputSize != baseOutputSize else {
            return filters
        }
        return filters + [C7Resize(width: Float(targetOutputSize.width), height: Float(targetOutputSize.height))]
    }

}

extension HarbethIO where Dest == MTLTexture {

    /// Starts a texture render task and returns a GPU task handle for status observation.
    ///
    /// This API is for advanced texture-first callers that need command-buffer status,
    /// completion observation, or explicit waiting without changing the existing
    /// `output()` and `transmitOutput(...)` behavior.
    public func startRenderTextureTask(diagnostics: RenderPlanDiagnostics? = nil) throws -> HarbethRenderTask<MTLTexture> {
        if filters.isEmpty {
            return .completed(identifier: identifier, output: element, diagnostics: diagnostics)
        }
        let plan = makeRenderPlan(input: element)
        let taskDiagnostics = diagnostics ?? plan.diagnostics
        prepareTextureLifecycle(for: plan, inputPixelFormat: element.pixelFormat)
        let commandBuffer = try makeCommandBuffer(for: nil)
        do {
            let outputTexture: MTLTexture
            var texturesToEnqueue: [MTLTexture] = []
            if shouldUseDoubleBuffer(input: element, plan: plan, minimumFilterCount: 1) {
                outputTexture = try doubleBuffering(input: element, plan: plan, commandBuffer: commandBuffer)
            } else {
                let result = try singleBuffer(input: element, plan: plan, commandBuffer: commandBuffer)
                outputTexture = result.0
                texturesToEnqueue = result.1
            }
            let task = HarbethRenderTask(
                identifier: identifier,
                commandBuffer: commandBuffer,
                output: outputTexture,
                diagnostics: taskDiagnostics,
                cleanup: {
                    Shared.shared.defaultTexturePool.enqueueTexturesSync(texturesToEnqueue)
                    Shared.shared.returnCommandBuffer(commandBuffer)
                }
            )
            commandBuffer.commit()
            return task
        } catch {
            Shared.shared.returnCommandBuffer(commandBuffer)
            throw error
        }
    }

    func renderManagedTexture() throws -> ManagedTextureResult {
        if filters.isEmpty {
            return ManagedTextureResult(texture: element, lease: nil)
        }
        let plan = makeRenderPlan(input: element)
        switch groupStrategy(for: plan) {
        case .batched:
            return try processManagedBatchedFilters(input: element, plan: plan)
        case .interleaved:
            return try processManagedInterleavedFilters(input: element, plan: plan)
        }
    }

    func transmitManagedTexture(complete: @escaping (Result<ManagedTextureResult, HarbethError>) -> Void) {
        if filters.isEmpty {
            complete(.success(ManagedTextureResult(texture: element, lease: nil)))
            return
        }
        let plan = makeRenderPlan(input: element)
        let operation = BlockOperation {
            do {
                let commandBuffer = try self.makeCommandBuffer()
                let result: ManagedTextureResult
                let intermediateLeases: [TextureLease]
                if self.shouldUseDoubleBuffer(input: self.element, plan: plan, minimumFilterCount: 4) {
                    let managed = try self.doubleBufferingManaged(input: self.element, plan: plan, commandBuffer: commandBuffer)
                    result = managed.result
                    intermediateLeases = managed.intermediateLeases
                } else {
                    let managed = try self.singleBufferManaged(input: self.element, plan: plan, commandBuffer: commandBuffer)
                    result = managed.result
                    intermediateLeases = managed.intermediateLeases
                }

                let releaseIntermediates = {
                    intermediateLeases.forEach { $0.release() }
                }

                if self.transmitOutputRealTimeCommit {
                    commandBuffer.addCompletedHandler { _ in
                        releaseIntermediates()
                    }
                    commandBuffer.realTimeCommit(identifier: self.identifier) {
                        complete(.success(result))
                    }
                    DispatchQueue.global().async {
                        commandBuffer.waitUntilCompleted()
                        Shared.shared.returnCommandBuffer(commandBuffer)
                    }
                } else {
                    commandBuffer.asyncCommit(identifier: self.identifier) { callbackResult in
                        switch callbackResult {
                        case .success:
                            releaseIntermediates()
                            Shared.shared.returnCommandBuffer(commandBuffer)
                            complete(.success(result))
                        case .failure(let error):
                            releaseIntermediates()
                            result.lease?.release()
                            Shared.shared.returnCommandBuffer(commandBuffer)
                            complete(.failure(HarbethError.toHarbethError(error)))
                        }
                    }
                }
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        }
        Shared.shared.renderOperationQueue.addOperation(operation)
    }

    private func processManagedBatchedFilters(input: MTLTexture, plan: RenderPlan) throws -> ManagedTextureResult {
        prepareTextureLifecycle(for: plan, inputPixelFormat: input.pixelFormat)
        let commandBuffer = try makeCommandBuffer(for: nil)
        let managed: (result: ManagedTextureResult, intermediateLeases: [TextureLease])
        if shouldUseDoubleBuffer(input: input, plan: plan, minimumFilterCount: 1) {
            managed = try doubleBufferingManaged(input: input, plan: plan, commandBuffer: commandBuffer)
        } else {
            managed = try singleBufferManaged(input: input, plan: plan, commandBuffer: commandBuffer)
        }
        commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
        managed.intermediateLeases.forEach { $0.release() }
        Shared.shared.returnCommandBuffer(commandBuffer)
        return managed.result
    }

    private func processManagedInterleavedFilters(input: MTLTexture, plan: RenderPlan) throws -> ManagedTextureResult {
        prepareTextureLifecycle(for: plan, inputPixelFormat: input.pixelFormat)
        var currentTexture = input
        var currentLease: TextureLease?

        for node in plan.graph.nodes {
            guard let filter = node.filter else { continue }
            let commandBuffer = try makeCommandBuffer(for: nil)
            let stage = try textureIOManaged(input: currentTexture, filter: filter, for: commandBuffer)
            commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
            Shared.shared.returnCommandBuffer(commandBuffer)

            if let previousLease = currentLease, previousLease.texture !== stage.texture {
                previousLease.release()
                currentLease = nil
            }

            if let producedLease = stage.producedLease {
                if producedLease.texture === stage.texture {
                    currentLease = producedLease
                } else {
                    producedLease.release()
                }
            }

            currentTexture = stage.texture
        }

        return ManagedTextureResult(texture: currentTexture, lease: currentLease)
    }

    private func singleBufferManaged(input: MTLTexture,
                                     plan: RenderPlan,
                                     commandBuffer: MTLCommandBuffer) throws -> (result: ManagedTextureResult, intermediateLeases: [TextureLease]) {
        var currentTexture = input
        var producedLeases: [TextureLease] = []

        for node in plan.graph.nodes {
            guard let filter = node.filter else { continue }
            let stage = try textureIOManaged(input: currentTexture, filter: filter, for: commandBuffer)
            if let lease = stage.producedLease {
                producedLeases.append(lease)
            }
            currentTexture = stage.texture
        }

        let finalLease = producedLeases.last(where: { $0.texture === currentTexture })
        let intermediateLeases = producedLeases.filter { lease in
            lease.texture !== currentTexture && lease.texture !== input
        }
        return (
            ManagedTextureResult(texture: currentTexture, lease: finalLease),
            intermediateLeases
        )
    }

    private func doubleBufferingManaged(input: MTLTexture,
                                        plan: RenderPlan,
                                        commandBuffer: MTLCommandBuffer) throws -> (result: ManagedTextureResult, intermediateLeases: [TextureLease]) {
        let filters = plan.graph.nodes.compactMap(\.filter)
        let width = input.width
        let height = input.height
        let pixelFormat = input.pixelFormat

        Shared.shared.prewarmTexturePool(resolutions: [(width: width, height: height, pixelFormat: pixelFormat)], count: 2)
        let leaseA = try TextureLoader.makeTextureLease(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ], identifier: identifier)
        let leaseB = try TextureLoader.makeTextureLease(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ], identifier: identifier)

        var currentInput = input
        var currentOutput = leaseA.texture

        for (index, filter) in filters.enumerated() {
            if let filter = filter as? C7CombinationBase {
                filter.identifier = identifier
                currentInput = try textureIO(input: currentInput, filter: filter, for: commandBuffer)
            } else {
                let preparedInput = try filter.combinationBegin(for: commandBuffer, source: currentInput, dest: currentOutput)
                let outputTexture = try filter.apply(form: preparedInput, to: currentOutput, for: commandBuffer, complete: nil)
                currentInput = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: currentInput)
                if index < filters.count - 1 {
                    currentOutput = currentOutput === leaseA.texture ? leaseB.texture : leaseA.texture
                }
            }
        }

        let finalLease: TextureLease?
        if currentInput === leaseA.texture {
            finalLease = leaseA
        } else if currentInput === leaseB.texture {
            finalLease = leaseB
        } else {
            finalLease = nil
        }

        let intermediateLeases: [TextureLease] = [leaseA, leaseB].filter { lease in
            lease !== finalLease
        }

        return (
            ManagedTextureResult(texture: currentInput, lease: finalLease),
            intermediateLeases
        )
    }
}
