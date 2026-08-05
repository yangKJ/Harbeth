//
//  HarbethIO.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//  https://github.com/yangKJ/Harbeth

import Foundation
@preconcurrency import MetalKit
@preconcurrency import CoreImage
import ImageIO
@preconcurrency import CoreMedia
@preconcurrency import CoreVideo

struct HarbethUncheckedTransfer<Value>: @unchecked Sendable {
    let value: Value
}

/// Quickly add filters to sources.
/// Support use `UIImage/NSImage, CGImage, CIImage, MTLTexture, CMSampleBuffer, CVPixelBuffer/CVImageBuffer`.
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
@frozen
public struct HarbethIO<Dest>: @unchecked Sendable {
    public typealias Element = Dest
    public let element: Dest
    public let filters: [C7FilterProtocol]

    /// Host-side frame sources often use `kCVPixelFormatType_32BGRA`.
    /// Keep the pixel format aligned with the source to avoid color channel issues.
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
    /// Whether to schedule the command buffer as soon as GPU execution is arranged,
    /// instead of waiting for full completion before continuing host-side flow.
    /// Recommended for low-latency frame processing paths.
    public var transmitOutputRealTimeCommit: Bool = false
    /// Enable double buffer optimization for metal filters
    /// When there are less than 4 filters, the traditional(singleBuffer) mode is better.
    public var enableDoubleBuffer: Bool = true
    /// The submission policy of asynchronous output maintains
    /// the independent delivery of each submission by default.
    public var submissionPolicy: RenderSubmissionPolicy = .independent

    /// Stable render intent for planning and diagnostics.
    var renderProfile: RenderProfile = .stablePreview

    /// The identifier of the HarbethIO instance.
    public let identifier: String

    private var setupedBufferPixelFormat = false

    private enum GroupStrategy {
        case batched, interleaved
    }

    private func castOutput<Value>(_ value: Value) throws -> Dest {
        guard let output = value as? Dest else {
            throw HarbethError.renderableInvalidOutputType
        }
        return output
    }

    private func castResult<Value>(_ result: Result<Value, HarbethError>) -> Result<Dest, HarbethError> {
        switch result {
        case .success(let value):
            do {
                return .success(try castOutput(value))
            } catch {
                return .failure(HarbethError.toHarbethError(error))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    public init(element: Dest, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }

    public init(element: Dest, filters: C7FilterProtocol...) {
        self.init(element: element, filters: filters)
    }

    public init(element: Dest, filters: [C7FilterProtocol]) {
        self.init(element: element, filters: filters, identifier: UUID().uuidString)
    }

    init(element: Dest, filter: C7FilterProtocol, identifier: String) {
        self.init(element: element, filters: [filter], identifier: identifier)
    }

    init(element: Dest, filters: [C7FilterProtocol], identifier: String) {
        self.element = element
        self.identifier = identifier
        self.filters = filters
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    public func transmitOutput(outputColorSpace: ImageColorSpaceContract? = nil) async throws -> Dest {
        let relay = RenderSubmissionCancellationRelay()
        let transfer: HarbethUncheckedTransfer<Dest> = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let handle = transmitOutput(outputColorSpace: outputColorSpace, complete: { result in
                    switch result {
                    case .success(let output):
                        continuation.resume(returning: HarbethUncheckedTransfer(value: output))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                })
                relay.store(handle)
            }
        }, onCancel: {
            relay.cancel()
        })
        return transfer.value
    }

    /// Directly convert the current input and filter chain into `RenderedFrame`.
    public func makeFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:]
    ) throws -> RenderedFrame {
        try renderFrame(
            profile: profile,
            derivative: derivative,
            outputColorSpace: outputColorSpace,
            metadata: metadata
        )
    }

    /// 同步添加滤镜，失败时返回原输入。
    /// 正式接入应优先使用会抛错的 `output()`；该便捷入口用于保持视觉连续性。
    public func filtered() -> Dest {
        do {
            return try output()
        } catch {
            HarbethLogger.log(
                .warning,
                category: "filtered",
                code: error.harbethDiagnosticCode,
                outcome: .fallback,
                metadata: error.harbethDiagnosticMetadata,
                message: error.harbethLocalizedDescription
            )
            return element
        }
    }

    /// Synchronously renders the current source and filter chain.
    /// - Returns: The rendered result after GPU work required by this output has completed.
    public func output(outputColorSpace: ImageColorSpaceContract? = nil) throws -> Dest {
        if self.filters.isEmpty {
            guard let outputColorSpace else { return element }
            switch element {
            case let ee as C7Image:
                return try castOutput(filtering(image: ee, outputColorSpace: outputColorSpace))
            case let ee as CIImage:
                return try castOutput(filtering(ciImage: ee, outputColorSpace: outputColorSpace))
            case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
                return try castOutput(filtering(cgImage: ee as! CGImage, outputColorSpace: outputColorSpace))
            case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
                return try castOutput(filtering(pixelBuffer: ee as! CVPixelBuffer, outputColorSpace: outputColorSpace))
            case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
                return try castOutput(filtering(sampleBuffer: ee as! CMSampleBuffer, outputColorSpace: outputColorSpace))
            default:
                return element
            }
        }
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.beginMonitoring(identifier)
        }
        defer { HarbethContext.shared.performanceMonitor.endMonitoring(identifier) }
        switch element {
        case let ee as MTLTexture:
            return try castOutput(filtering(texture: ee))
        case let ee as C7Image:
            return try castOutput(filtering(image: ee, outputColorSpace: outputColorSpace))
        case let ee as CIImage:
            return try castOutput(filtering(ciImage: ee, outputColorSpace: outputColorSpace))
        case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
            return try castOutput(filtering(cgImage: ee as! CGImage, outputColorSpace: outputColorSpace))
        case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
            return try castOutput(filtering(pixelBuffer: ee as! CVPixelBuffer, outputColorSpace: outputColorSpace))
        case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
            return try castOutput(filtering(sampleBuffer: ee as! CMSampleBuffer, outputColorSpace: outputColorSpace))
        default:
            return element
        }
    }

    /// Convenience callback form of `transmitOutput(outputColorSpace:complete:)`.
    @discardableResult
    public func transmitOutput(
        success: @escaping @Sendable (Dest) -> Void,
        failed: (@Sendable (HarbethError) -> Void)? = nil
    ) -> RenderSubmissionHandle {
        transmitOutput(outputColorSpace: nil) { result in
            switch result {
            case .success(let output):
                success(output)
            case .failure(let error):
                failed?(HarbethError.toHarbethError(error))
            }
        }
    }

    /// Submits the current source and filter chain without blocking the caller for GPU completion.
    ///
    /// Filtered work is encoded on Harbeth's render operation queue. The completion closure is not
    /// delivered on a guaranteed queue; UI callers must explicitly hop to the main actor. A no-filter
    /// fast path may complete inline because no asynchronous render work exists.
    /// - Parameters:
    ///   - outputColorSpace: Optional output color-space contract applied before delivery.
    ///   - complete: Receives the rendered result or a structured ``HarbethError``.
    @discardableResult
    public func transmitOutput(
        outputColorSpace: ImageColorSpaceContract? = nil,
        complete: @escaping @Sendable (Result<Dest, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        if self.filters.isEmpty {
            do {
                complete(.success(try output(outputColorSpace: outputColorSpace)))
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
            return completedSubmissionHandle()
        }
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.beginMonitoring(identifier)
        }
        switch element {
        case let ee as MTLTexture:
            return filtering(texture: ee, complete: {
                HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
                complete(self.castResult($0))
            })
        case let ee as C7Image:
            return filtering(image: ee, outputColorSpace: outputColorSpace, complete: {
                HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
                complete(self.castResult($0))
            })
        case let ee as CIImage:
            return filtering(ciImage: ee, outputColorSpace: outputColorSpace, complete: {
                HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
                complete(self.castResult($0))
            })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CGImage.typeID:
            return filtering(cgImage: ee as! CGImage, outputColorSpace: outputColorSpace, complete: {
                HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
                complete(self.castResult($0))
            })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CVPixelBufferGetTypeID():
            return filtering(pixelBuffer: ee as! CVPixelBuffer, outputColorSpace: outputColorSpace, complete: {
                HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
                complete(self.castResult($0))
            })
        case let ee where CFGetTypeID(ee as CFTypeRef) == CMSampleBufferGetTypeID():
            return filtering(sampleBuffer: ee as! CMSampleBuffer, outputColorSpace: outputColorSpace, complete: {
                HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
                complete(self.castResult($0))
            })
        default:
            complete(.success(element))
            HarbethContext.shared.performanceMonitor.endMonitoring(self.identifier)
            return completedSubmissionHandle()
        }
    }
    /// Asynchronous convert to texture and add filters.
    /// - Parameters:
    ///   - texture: Input metal texture.
    ///   - complete: The conversion is complete.
    @discardableResult
    public func filtering(texture: MTLTexture, complete: @escaping C7TextureResultBlock) -> RenderSubmissionHandle {
        if self.filters.isEmpty {
            complete(.success(texture))
            return completedSubmissionHandle()
        }
        let program = makeRenderProgram(input: texture)
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: texture.pixelFormat)
        let operationState = HarbethUncheckedTransfer(value: (io: self, texture: texture, program: program))
        return HarbethContext.shared.submitRenderOperation(
            sourceIdentifier: identifier,
            policy: submissionPolicy,
            execute: { submission in
                let io = operationState.value.io
                let inputTexture = operationState.value.texture
                let program = operationState.value.program
                do {
                    // 实时模式只等待命令进入 scheduled，不等待 GPU 完成。
                    let deliversWhenScheduled = io.transmitOutputRealTimeCommit && io.element is MTLTexture
                    if deliversWhenScheduled {
                        guard let commandBuffer = submission.makeCommandBuffer() else {
                            if submission.isActive {
                                submission.deliver { complete(.failure(.commandBuffer)) }
                            }
                            return
                        }
                        let rendering: RawTextureRendering
                        do {
                            if io.shouldUseDoubleBuffer(input: inputTexture, program: program, minimumFilterCount: 4) {
                                rendering = try io.doubleBuffering(input: inputTexture, program: program, commandBuffer: commandBuffer)
                            } else {
                                rendering = try io.singleBuffer(input: inputTexture, program: program, commandBuffer: commandBuffer)
                            }
                        } catch {
                            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                            throw error
                        }
                        guard submission.claimCommit() else {
                            io.recycleRawTextures(rendering.failureRecycling)
                            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                            return
                        }
                        let cleanupState = RawTextureScheduledCleanupState()
                        let commandBufferTransfer = HarbethUncheckedTransfer(value: commandBuffer)
                        commandBuffer.addCompletedHandler { _ in
                            if let delivered = cleanupState.recordCompletion() {
                                io.recycleRawTextures(rendering.recycling(deliverySucceeded: delivered))
                            }
                        }
                        // scheduled 后立即交付，保持低延迟语义。
                        commandBuffer.realTimeCommit(identifier: io.identifier) {
                            let delivered = submission.deliver {
                                complete(.success(rendering.output))
                            }
                            if let delivered = cleanupState.recordDelivery(delivered) {
                                io.recycleRawTextures(rendering.recycling(deliverySucceeded: delivered))
                            }
                        }
                        // 后台等待 GPU 结束并完成 command buffer 清理。
                        DispatchQueue.global().async {
                            commandBufferTransfer.value.waitUntilCompleted()
                            HarbethContext.shared.recycleCommandBuffer(commandBufferTransfer.value)
                        }
                    } else {
                        // 普通异步模式在 GPU 完成后交付。
                        guard let commandBuffer = submission.makeCommandBuffer() else {
                            if submission.isActive {
                                submission.deliver { complete(.failure(.commandBuffer)) }
                            }
                            return
                        }
                        let rendering: RawTextureRendering
                        do {
                            if io.shouldUseDoubleBuffer(input: inputTexture, program: program, minimumFilterCount: 4) {
                                rendering = try io.doubleBuffering(input: inputTexture, program: program, commandBuffer: commandBuffer)
                            } else {
                                rendering = try io.singleBuffer(input: inputTexture, program: program, commandBuffer: commandBuffer)
                            }
                        } catch {
                            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                            throw error
                        }
                        let callbackState = HarbethUncheckedTransfer(value: (commandBuffer: commandBuffer, rendering: rendering))
                        guard submission.claimCommit() else {
                            io.recycleRawTextures(rendering.failureRecycling)
                            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                            return
                        }
                        commandBuffer.asyncCommit(identifier: io.identifier) { result in
                            switch result {
                            case .success:
                                let delivered = submission.deliver {
                                    complete(.success(callbackState.value.rendering.output))
                                }
                                io.recycleRawTextures(callbackState.value.rendering.recycling(deliverySucceeded: delivered))
                                HarbethContext.shared.recycleCommandBuffer(callbackState.value.commandBuffer)
                            case .failure(let error):
                                io.recycleRawTextures(callbackState.value.rendering.failureRecycling)
                                HarbethContext.shared.recycleCommandBuffer(callbackState.value.commandBuffer)
                                submission.deliver {
                                    complete(.failure(HarbethError.toHarbethError(error)))
                                }
                            }
                        }
                    }
                } catch {
                    submission.deliver {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                }
            },
            onDiscard: { _ in complete(.failure(.renderableTaskCancelled)) }
        )
    }

    private func completedSubmissionHandle() -> RenderSubmissionHandle {
        .completed(sourceIdentifier: identifier, policy: submissionPolicy)
    }
}

public extension HarbethIO where Dest == CIImage {
    /// Synchronously render and return Core Image frames with complete texture ownership and color contracts.
    func outputTextureBackedFrame(outputColorSpace: ImageColorSpaceContract? = nil) throws -> TextureBackedCIImageFrame {
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.beginMonitoring(identifier)
        }
        defer { HarbethContext.shared.performanceMonitor.endMonitoring(identifier) }
        let frame = try makeFrame(profile: renderProfile, outputColorSpace: outputColorSpace)
        let options: [CIImageOption: Any]? = frame.colorSpace.map { [.colorSpace: $0] }
        guard var image = CIImage(mtlTexture: frame.texture, options: options) else {
            throw HarbethError.texture2Image
        }
        if element.extent.origin != .zero {
            image = image.transformed(
                by: CGAffineTransform(
                    translationX: element.extent.origin.x,
                    y: element.extent.origin.y
                )
            )
        }
        if mirrored || element.pixelBuffer != nil {
            image = image.oriented(.downMirrored)
        }
        return TextureBackedCIImageFrame(image: image, owner: frame)
    }
}

struct ManagedTextureResult: @unchecked Sendable {
    let texture: MTLTexture
    let lease: TextureLease?
}

struct EncodedTextureProgram: @unchecked Sendable {
    let output: MTLTexture
    let allocatedTextures: [MTLTexture]
}

/// 把线性渲染程序编码进调用方命令缓冲区后的内部结果。
/// 缓冲区完成前，所有纹理租约都保持独占。
struct EncodedManagedTextureProgram: @unchecked Sendable {
    let result: ManagedTextureResult
    let producedLeases: [TextureLease]

    func retainUntilCompleted(by commandBuffer: MTLCommandBuffer) {
        producedLeases.forEach { $0.retainUntilCompleted(by: commandBuffer) }
    }

    func releaseAll() {
        producedLeases.forEach { $0.release() }
    }

    func releaseIntermediates() {
        producedLeases.forEach { lease in
            if lease !== result.lease {
                lease.release()
            }
        }
    }
}

private struct RawTextureStage {
    let texture: MTLTexture
    let allocatedDestination: MTLTexture?
}

struct RawTextureRendering {
    let output: MTLTexture
    let successRecycling: [MTLTexture]
    let failureRecycling: [MTLTexture]

    func recycling(deliverySucceeded: Bool) -> [MTLTexture] {
        deliverySucceeded ? successRecycling : failureRecycling
    }
}

final class RawTextureScheduledCleanupState: @unchecked Sendable {
    private let lock = NSLock()
    private var commandCompleted = false
    private var deliverySucceeded: Bool?
    private var cleanupClaimed = false

    func recordCompletion() -> Bool? {
        lock.lock()
        commandCompleted = true
        let delivery = takeCleanupDecisionIfReadyLocked()
        lock.unlock()
        return delivery
    }

    func recordDelivery(_ succeeded: Bool) -> Bool? {
        lock.lock()
        deliverySucceeded = succeeded
        let delivery = takeCleanupDecisionIfReadyLocked()
        lock.unlock()
        return delivery
    }

    private func takeCleanupDecisionIfReadyLocked() -> Bool? {
        guard commandCompleted, let deliverySucceeded, cleanupClaimed == false else { return nil }
        cleanupClaimed = true
        return deliverySucceeded
    }
}

extension HarbethIO {
    private func filtering(texture: MTLTexture) throws -> MTLTexture {
        let program = makeRenderProgram(input: texture)
        return try executeRenderProgram(input: texture, program: program)
    }

    func executeRenderProgram(input texture: MTLTexture, program: RenderExecutionProgram) throws -> MTLTexture {
        guard program.sourceFilterFingerprint == filters.chainRecipe.fingerprint,
              program.diagnostics.inputSize == C7Size(texture: texture) else {
            throw HarbethError.configurationInvalid(
                "RenderExecutionProgram does not match the HarbethIO input or filter chain."
            )
        }
        guard program.steps.isEmpty == false else { return texture }
        switch groupStrategy(for: program.plan) {
        case .batched:
            return try processBatchedFilters(input: texture, program: program)
        case .interleaved:
            return try processInterleavedFilters(input: texture, program: program)
        }
    }

    private func processBatchedFilters(input: MTLTexture, program: RenderExecutionProgram) throws -> MTLTexture {
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: input.pixelFormat)
        let commandBuffer = try makeCommandBuffer(for: nil)
        let rendering: RawTextureRendering
        do {
            if shouldUseDoubleBuffer(input: input, program: program, minimumFilterCount: 1) {
                rendering = try doubleBuffering(input: input, program: program, commandBuffer: commandBuffer)
            } else {
                rendering = try singleBuffer(input: input, program: program, commandBuffer: commandBuffer)
            }
        } catch {
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            throw error
        }
        do {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
            recycleRawTextures(rendering.successRecycling)
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            return rendering.output
        } catch {
            recycleRawTextures(rendering.failureRecycling)
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            throw error
        }
    }

    private func processInterleavedFilters(input: MTLTexture, program: RenderExecutionProgram) throws -> MTLTexture {
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: input.pixelFormat)
        var outputTexture = input
        var ownedOutput: MTLTexture?
        for step in program.steps {
            let commandBuffer: MTLCommandBuffer
            do {
                commandBuffer = try makeCommandBuffer(for: nil)
            } catch {
                recycleRawTextures(ownedOutput.map { [$0] } ?? [])
                throw error
            }
            let previousOwnedOutput = ownedOutput
            let stage: RawTextureStage
            do {
                stage = try textureIO(input: outputTexture, filter: step.filter, for: commandBuffer)
            } catch {
                recycleRawTextures(previousOwnedOutput.map { [$0] } ?? [])
                HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                throw error
            }
            outputTexture = stage.texture
            do {
                try commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
                recycleRawTextures(
                    [previousOwnedOutput, stage.allocatedDestination]
                        .compactMap { $0 }
                        .filter { $0 !== outputTexture }
                )
                if outputTexture === stage.allocatedDestination {
                    ownedOutput = stage.allocatedDestination
                } else if outputTexture === previousOwnedOutput {
                    ownedOutput = previousOwnedOutput
                } else {
                    ownedOutput = nil
                }
                HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            } catch {
                recycleRawTextures([previousOwnedOutput, stage.allocatedDestination].compactMap { $0 })
                HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                throw error
            }
        }
        return outputTexture
    }
}

extension HarbethIO {
    func makeRenderProgram(
        input texture: MTLTexture,
        derivative: ImageDerivativeSpec? = nil,
        sourceDescriptor: ImageSourceDescriptor? = nil
    ) -> RenderExecutionProgram {
        let inputSize = C7Size(texture: texture)
        // Cache key covers exactly what `GraphCompiler.compile` consumes on this path: the filter
        // chain recipe (type + kernel + parameters, via the same `chainRecipe` fingerprint ImageNode
        // uses), the input dimensions, and the render profile (which also fixes the derivative).
        // `compilationSource` is constant (`.filtersPrimitive`) here, so it is a fixed prefix.
        // Same key ⇒ identical plan, so a stable chain rendered repeatedly (realtime / video) only
        // compiles the render graph once instead of on every frame.
        let effectiveDerivative = derivative ?? renderProfile.defaultDerivativeSpec
        let cacheKey = [
            "filtersPrimitive",
            "executionProgram=v1",
            filters.chainRecipe.fingerprint,
            "input=\(inputSize.width)x\(inputSize.height)",
            "profile=\(renderProfile.rawValue)",
            "derivative=\(effectiveDerivative.fingerprint)",
            "source=\(sourceDescriptor?.fingerprint ?? "none")",
        ].joined(separator: "|")
        let program = RenderExecutionCompiler.compile(
            filters: filters,
            inputSize: inputSize,
            profile: renderProfile,
            derivative: effectiveDerivative,
            compilationSource: .filtersPrimitive,
            sourceDescriptor: sourceDescriptor,
            planCacheKey: cacheKey
        )
        HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup(
            "renderPlan",
            hit: program.reusedCachedPlan
        )
        if HarbethContext.shared.enablePerformanceMonitor {
            let plan = program.plan
            HarbethContext.shared.performanceMonitor.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                HarbethContext.shared.performanceMonitor.recordReadbackBoundary(identifier)
            }
            let diagnostics = plan.diagnostics
            HarbethContext.shared.performanceMonitor.recordRenderOptimizationPlan(identifier, plan: diagnostics.optimizationPlan)
            if diagnostics.outputContract.requiresAlphaConversion {
                HarbethContext.shared.performanceMonitor.recordAlphaConversion(identifier, contract: diagnostics.outputContract.alpha)
            }
            if diagnostics.outputContract.requiresColorSpaceConversion {
                HarbethContext.shared.performanceMonitor.recordColorConversion(identifier, contract: diagnostics.outputContract.colorSpace)
            }
        }
        return program
    }

    private func prepareTextureLifecycle(for plan: RenderPlan, inputPixelFormat: MTLPixelFormat) {
        let reservations = plan.diagnostics.optimizationPlan.prewarmReservations
        guard reservations.isEmpty == false else { return }
        // Execution starts immediately after planning, so the reservations must be
        // materialized synchronously to have a real chance to improve reuse.
        HarbethContext.shared.prewarmTexturePoolSync(
            reservations: reservations,
            fallbackPixelFormat: inputPixelFormat,
            defaultCount: 1
        )
    }

    private func prewarmDoubleBufferReservations(for plan: RenderPlan, fallbackSize: C7Size, inputPixelFormat: MTLPixelFormat) {
        let reservations = plan.diagnostics.optimizationPlan.prewarmReservations
        let effectiveReservations: [RenderTextureReservation]
        if reservations.isEmpty {
            effectiveReservations = [
                RenderTextureReservation(
                    stageIndices: Array(0..<max(plan.graph.nodes.count, 1)),
                    size: fallbackSize,
                    pixelFormat: PixelFormatContract(pixelFormat: inputPixelFormat, preservesInput: false),
                    reason: .transientReuse,
                    count: 2
                )
            ]
        } else {
            effectiveReservations = reservations
        }
        HarbethContext.shared.prewarmTexturePoolSync(
            reservations: effectiveReservations,
            fallbackPixelFormat: inputPixelFormat,
            defaultCount: 2
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
        var resize = filter.resize(input: C7Size(texture: sourceTexture))
        // Calculate target size considering device limits
        let (deviceMaxWidth, deviceMaxHeight) = Device.makeTexture2DMaxSize(width: resize.width, height: resize.height)
        resize = C7Size(width: deviceMaxWidth, height: deviceMaxHeight)
        // Host-side frame sources often use `kCVPixelFormatType_32BGRA`.
        // Keep the output pixel format aligned with the source to avoid channel mismatch.
        let texture = try TextureLoader.makeTexture(
            width: resize.width,
            height: resize.height,
            options: [
                .texturePixelFormat: targetPixelFormat,
                .textureUsage: outputTextureUsage(for: filter)
            ],
            identifier: identifier
        )
        if HarbethContext.shared.enablePerformanceMonitor {
            if sourceTexture.pixelFormat != targetPixelFormat {
                HarbethContext.shared.performanceMonitor.recordPixelFormatConversion(
                    identifier,
                    from: sourceTexture.pixelFormat,
                    to: targetPixelFormat
                )
            }
            // Record memory allocation
            let bytesPerPixel = 4 // RGBA8
            let memoryBytes = resize.width * resize.height * bytesPerPixel
            HarbethContext.shared.performanceMonitor.recordMemoryAllocation(identifier, bytes: memoryBytes, source: "Texture")
        }
        return texture
    }

    private func createDestTextureLease(with sourceTexture: MTLTexture, filter: C7FilterProtocol) throws -> TextureLease? {
        guard createDestTexture, (filter.parameterDescription["needCreateDestTexture"] as? Bool ?? true) else {
            return nil
        }
        let targetPixelFormat = setupBufferPixelFormat(with: sourceTexture)
        var resize = filter.resize(input: C7Size(texture: sourceTexture))
        let (deviceMaxWidth, deviceMaxHeight) = Device.makeTexture2DMaxSize(width: resize.width, height: resize.height)
        resize = C7Size(width: deviceMaxWidth, height: deviceMaxHeight)
        let lease = try TextureLoader.makeTextureLease(
            width: resize.width,
            height: resize.height,
            options: [
                .texturePixelFormat: targetPixelFormat,
                .textureUsage: outputTextureUsage(for: filter)
            ],
            identifier: identifier
        )
        if HarbethContext.shared.enablePerformanceMonitor {
            if sourceTexture.pixelFormat != targetPixelFormat {
                HarbethContext.shared.performanceMonitor.recordPixelFormatConversion(
                    identifier,
                    from: sourceTexture.pixelFormat,
                    to: targetPixelFormat
                )
            }
            let bytesPerPixel = 4
            let memoryBytes = resize.width * resize.height * bytesPerPixel
            HarbethContext.shared.performanceMonitor.recordMemoryAllocation(
                identifier,
                bytes: memoryBytes,
                source: "TextureLease"
            )
        }
        return lease
    }

    private func outputTextureUsage(for filter: C7FilterProtocol) -> MTLTextureUsage {
        switch filter.modifier {
        case .render:
            return [.shaderRead, .shaderWrite, .renderTarget]
        case .compute, .blit, .mps, .advancedMetal:
            return [.shaderRead, .shaderWrite]
        }
    }

    /// Do you need to create a new metal texture command buffer.
    private func makeCommandBuffer(for buffer: MTLCommandBuffer? = nil) throws -> MTLCommandBuffer {
        if let commandBuffer = buffer { return commandBuffer }
        guard let commandBuffer = HarbethContext.shared.makeCommandBuffer() else { throw HarbethError.commandBuffer }
        return commandBuffer
    }

    /// Create a new texture based on the filter content.
    private func textureIO(input texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer) throws -> RawTextureStage {
        let destTexture = try createDestTexture(with: texture, filter: filter)
        let allocatedDestination = destTexture === texture ? nil : destTexture
        do {
            if let pipelineFilter = filter as? C7FilterPipelineProtocol {
                let output = try FilterPipelineExecutor.apply(
                    filter: pipelineFilter,
                    source: texture,
                    destination: destTexture,
                    commandBuffer: buffer
                )
                return RawTextureStage(texture: output, allocatedDestination: allocatedDestination)
            }
            let inputTexture = try filter.combinationBegin(for: buffer, source: texture, dest: destTexture)
            let outputTexture = try filter.apply(form: inputTexture, to: destTexture, for: buffer, complete: nil)
            let output = try filter.combinationAfter(for: buffer, input: outputTexture, source: texture)
            return RawTextureStage(texture: output, allocatedDestination: allocatedDestination)
        } catch {
            recycleRawTextures(allocatedDestination.map { [$0] } ?? [])
            throw error
        }
    }

    private func textureIOManaged(input texture: MTLTexture, filter: C7FilterProtocol, for buffer: MTLCommandBuffer) throws -> ManagedTextureResult {
        let destLease = try createDestTextureLease(with: texture, filter: filter)
        let destTexture = destLease?.texture ?? texture
        do {
            if let pipelineFilter = filter as? C7FilterPipelineProtocol {
                let finalTexture = try FilterPipelineExecutor.apply(
                    filter: pipelineFilter,
                    source: texture,
                    destination: destTexture,
                    commandBuffer: buffer
                )
                return ManagedTextureResult(texture: finalTexture, lease: destLease)
            }
            let inputTexture = try filter.combinationBegin(for: buffer, source: texture, dest: destTexture)
            let outputTexture = try filter.apply(form: inputTexture, to: destTexture, for: buffer, complete: nil)
            let finalTexture = try filter.combinationAfter(for: buffer, input: outputTexture, source: texture)
            return ManagedTextureResult(texture: finalTexture, lease: destLease)
        } catch {
            destLease?.release()
            throw error
        }
    }

    private func singleBuffer(input: MTLTexture, program: RenderExecutionProgram, commandBuffer: MTLCommandBuffer) throws -> RawTextureRendering {
        var currentTexture = input
        var allocatedTextures: [MTLTexture] = []
        do {
            for step in program.steps {
                let stage = try textureIO(input: currentTexture, filter: step.filter, for: commandBuffer)
                if let allocatedDestination = stage.allocatedDestination {
                    allocatedTextures.append(allocatedDestination)
                }
                currentTexture = stage.texture
            }
        } catch {
            recycleRawTextures(allocatedTextures)
            throw error
        }
        let finalTexture = currentTexture
        return RawTextureRendering(
            output: finalTexture,
            successRecycling: allocatedTextures.filter { $0 !== finalTexture },
            failureRecycling: allocatedTextures
        )
    }

    private func shouldUseDoubleBuffer(input: MTLTexture, program: RenderExecutionProgram, minimumFilterCount: Int) -> Bool {
        let filters = program.filters
        guard enableDoubleBuffer, filters.count >= minimumFilterCount else { return false }
        guard program.plan.containsBoundary == false else { return false }
        guard program.steps.dropLast().allSatisfy({ $0.lifecycleAction.isTransient }) else { return false }
        var inputSize = C7Size(texture: input)
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
    private func doubleBuffering(input: MTLTexture, program: RenderExecutionProgram, commandBuffer: MTLCommandBuffer) throws -> RawTextureRendering {
        let filters = program.filters
        let width = input.width
        let height = input.height
        let pixelFormat = input.pixelFormat
        let requiresRenderTarget = filters.contains { filter in
            if case .render = filter.modifier { return true }
            return false
        }
        if requiresRenderTarget == false {
            prewarmDoubleBufferReservations(
                for: program.plan,
                fallbackSize: C7Size(width: width, height: height),
                inputPixelFormat: pixelFormat
            )
        }
        let doubleBufferUsage: MTLTextureUsage = requiresRenderTarget
            ? [.shaderRead, .shaderWrite, .renderTarget]
            : [.shaderRead, .shaderWrite]
        let textureA = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [
                .texturePixelFormat: pixelFormat,
                .textureUsage: doubleBufferUsage
            ],
            identifier: identifier
        )
        let textureB: MTLTexture
        do {
            textureB = try TextureLoader.makeTexture(
                width: width,
                height: height,
                options: [
                    .texturePixelFormat: pixelFormat,
                    .textureUsage: doubleBufferUsage
                ],
                identifier: identifier
            )
        } catch {
            recycleRawTextures([textureA])
            throw error
        }
        var currentInput = input
        var currentOutput = textureA
        do {
            for (index, filter) in filters.enumerated() {
                if let filter = filter as? C7FilterPipelineProtocol {
                    currentInput = try FilterPipelineExecutor.apply(
                        filter: filter,
                        source: currentInput,
                        destination: currentOutput,
                        commandBuffer: commandBuffer
                    )
                    if index < filters.count - 1 {
                        currentOutput = currentOutput === textureA ? textureB : textureA
                    }
                    continue
                }
                let preparedInput = try filter.combinationBegin(
                    for: commandBuffer,
                    source: currentInput,
                    dest: currentOutput
                )
                let outputTexture = try filter.apply(
                    form: preparedInput,
                    to: currentOutput,
                    for: commandBuffer,
                    complete: nil
                )
                currentInput = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: currentInput)
                if index < filters.count - 1 {
                    currentOutput = currentOutput === textureA ? textureB : textureA
                }
            }
        } catch {
            recycleRawTextures([textureA, textureB])
            throw error
        }
        let finalTexture = currentInput
        let allocatedTextures = [textureA, textureB]
        return RawTextureRendering(
            output: finalTexture,
            successRecycling: allocatedTextures.filter { $0 !== finalTexture },
            failureRecycling: allocatedTextures
        )
    }

    private func recycleRawTextures(_ textures: [MTLTexture]) {
        var seen = Set<ObjectIdentifier>()
        let uniqueTextures = textures.filter { seen.insert(ObjectIdentifier($0)).inserted }
        HarbethContext.shared.texturePool.enqueueTexturesSync(uniqueTextures)
    }

    private func filtering(pixelBuffer: CVPixelBuffer, outputColorSpace: ImageColorSpaceContract? = nil) throws -> CVPixelBuffer {
        let inTexture = try TextureLoader(with: pixelBuffer).texture
        let outputColorSpace = resolvedOutputColorSpace(
            inputSize: C7Size(texture: inTexture),
            outputColorSpace: outputColorSpace
        )
        let texture = try filtering(texture: inTexture)
        let outputPixelBuffer = try outputColorSpace.preservesInput
        ? pixelBuffer.c7.copyOutputTextureToCompatiblePixelBuffer(with: texture)
        : pixelBuffer.c7.makeCompatibleOutputPixelBuffer(for: texture)
        outputPixelBuffer.c7.setColorSpaceAttachments(outputColorSpace)
        return outputPixelBuffer
    }

    private func filtering(sampleBuffer: CMSampleBuffer, outputColorSpace: ImageColorSpaceContract? = nil) throws -> CMSampleBuffer {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw HarbethError.CMSampleBufferToCVPixelBuffer
        }
        let outputColorSpace = resolvedOutputColorSpace(
            inputSize: C7Size(pixelBuffer: pixelBuffer),
            outputColorSpace: outputColorSpace
        )
        let outputPixelBuffer = try filtering(pixelBuffer: pixelBuffer, outputColorSpace: outputColorSpace)
        guard let buffer = outputPixelBuffer.c7.toCMSampleBuffer(reference: sampleBuffer) else {
            throw HarbethError.CVPixelBufferToCMSampleBuffer
        }
        if outputColorSpace.preservesInput == false, let imageBuffer = CMSampleBufferGetImageBuffer(buffer) {
            imageBuffer.c7.setColorSpaceAttachments(outputColorSpace)
        }
        return buffer
    }

    private func filtering(cgImage: CGImage, outputColorSpace: ImageColorSpaceContract? = nil) throws -> CGImage {
        let inTexture = try TextureLoader(with: cgImage).texture
        let outputColorSpace = resolvedOutputColorSpace(
            inputSize: C7Size(texture: inTexture),
            outputColorSpace: outputColorSpace
        )
        let texture = try filtering(texture: inTexture)
        guard let cgImg = texture.c7.toCGImage(colorSpace: outputColorSpace.cgColorSpace ?? cgImage.colorSpace) else {
            throw HarbethError.texture2Image
        }
        return cgImg
    }

    private func filtering(ciImage: CIImage, outputColorSpace: ImageColorSpaceContract? = nil) throws -> CIImage {
        let inTexture = try TextureLoader(with: ciImage).texture
        let outputColorSpace = resolvedOutputColorSpace(
            inputSize: C7Size(texture: inTexture),
            outputColorSpace: outputColorSpace
        )
        let texture = try filtering(texture: inTexture)
        return try makeCIImage(texture: texture, source: ciImage, outputColorSpace: outputColorSpace)
    }

    private func makeCIImage(texture: MTLTexture, source: CIImage, outputColorSpace: ImageColorSpaceContract) throws -> CIImage {
        guard let cgImage = texture.c7.toCGImage(
            colorSpace: outputColorSpace.cgColorSpace ?? source.colorSpace
        ) else {
            throw HarbethError.texture2Image
        }
        let image = CIImage(cgImage: cgImage)
        return mirrored ? image.oriented(.downMirrored) : image
    }

    private func filtering(image: C7Image, outputColorSpace: ImageColorSpaceContract? = nil) throws -> C7Image {
        let inTexture = try TextureLoader(with: image).texture
        let outputColorSpace = resolvedOutputColorSpace(
            inputSize: C7Size(texture: inTexture),
            outputColorSpace: outputColorSpace
        )
        let texture = try filtering(texture: inTexture)
        guard let outputImage = texture.c7.toImage(
            colorSpace: outputColorSpace.cgColorSpace ?? image.c7.toCGImage()?.colorSpace
        ) else {
            throw HarbethError.texture2Image
        }
        return outputImage
    }

    private func filtering(
        pixelBuffer: CVPixelBuffer,
        outputColorSpace: ImageColorSpaceContract? = nil,
        complete: @escaping @Sendable (Result<CVPixelBuffer, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        do {
            let texture = try TextureLoader(with: pixelBuffer).texture
            let source = HarbethUncheckedTransfer(value: pixelBuffer)
            let outputColorSpace = resolvedOutputColorSpace(
                inputSize: C7Size(texture: texture),
                outputColorSpace: outputColorSpace
            )
            return filtering(texture: texture, complete: { result in
                switch result {
                case .success(let outputTexture):
                    do {
                        let outputPixelBuffer = try source.value.c7.copyOutputTextureToCompatiblePixelBuffer(with: outputTexture)
                        outputPixelBuffer.c7.setColorSpaceAttachments(outputColorSpace)
                        complete(.success(outputPixelBuffer))
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                case .failure(let error):
                    complete(.failure(error))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
            return completedSubmissionHandle()
        }
    }

    private func filtering(
        sampleBuffer: CMSampleBuffer,
        outputColorSpace: ImageColorSpaceContract? = nil,
        complete: @escaping @Sendable (Result<CMSampleBuffer, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            complete(.failure(HarbethError.CMSampleBufferToCVPixelBuffer))
            return completedSubmissionHandle()
        }
        let outputColorSpace = resolvedOutputColorSpace(
            inputSize: C7Size(pixelBuffer: pixelBuffer),
            outputColorSpace: outputColorSpace
        )
        let source = HarbethUncheckedTransfer(value: sampleBuffer)
        return filtering(pixelBuffer: pixelBuffer, outputColorSpace: outputColorSpace, complete: { result in
            switch result {
            case .success(let outputPixelBuffer):
                guard let buffer = outputPixelBuffer.c7.toCMSampleBuffer(reference: source.value) else {
                    complete(.failure(HarbethError.CVPixelBufferToCMSampleBuffer))
                    return
                }
                if outputColorSpace.preservesInput == false, let imageBuffer = CMSampleBufferGetImageBuffer(buffer) {
                    imageBuffer.c7.setColorSpaceAttachments(outputColorSpace)
                }
                complete(.success(buffer))
            case .failure(let error):
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        })
    }

    private func filtering(
        cgImage: CGImage,
        outputColorSpace: ImageColorSpaceContract? = nil,
        complete: @escaping @Sendable (Result<CGImage, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        do {
            let texture = try TextureLoader(with: cgImage).texture
            let outputColorSpace = resolvedOutputColorSpace(
                inputSize: C7Size(texture: texture),
                outputColorSpace: outputColorSpace
            )
            return filtering(texture: texture, complete: { result in
                    switch result {
                    case .success(let texture):
                        guard let outputImage = texture.c7.toCGImage(
                            colorSpace: outputColorSpace.cgColorSpace ?? cgImage.colorSpace
                        ) else {
                            complete(.failure(HarbethError.texture2Image))
                            return
                        }
                        complete(.success(outputImage))
                    case .failure(let error):
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
            return completedSubmissionHandle()
        }
    }

    private func filtering(
        ciImage: CIImage,
        outputColorSpace: ImageColorSpaceContract? = nil,
        complete: @escaping @Sendable (Result<CIImage, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        do {
            let texture = try TextureLoader(with: ciImage).texture
            let outputColorSpace = resolvedOutputColorSpace(
                inputSize: C7Size(texture: texture),
                outputColorSpace: outputColorSpace
            )
            return filtering(texture: texture, complete: { result in
                switch result {
                case .success(let texture):
                    do {
                        complete(.success(
                            try makeCIImage(
                                texture: texture,
                                source: ciImage,
                                outputColorSpace: outputColorSpace
                            )
                        ))
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                case .failure(let error):
                    complete(.failure(error))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
            return completedSubmissionHandle()
        }
    }

    private func filtering(
        image: C7Image,
        outputColorSpace: ImageColorSpaceContract? = nil,
        complete: @escaping @Sendable (Result<C7Image, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        do {
            let texture = try TextureLoader(with: image).texture
            let outputColorSpace = resolvedOutputColorSpace(
                inputSize: C7Size(texture: texture),
                outputColorSpace: outputColorSpace
            )
            return filtering(texture: texture, complete: { result in
                switch result {
                case .success(let texture):
                    guard let outputImage = texture.c7.toImage(
                        colorSpace: outputColorSpace.cgColorSpace ?? image.c7.toCGImage()?.colorSpace
                    ) else {
                        complete(.failure(HarbethError.texture2Image))
                        return
                    }
                    complete(.success(outputImage))
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
            return completedSubmissionHandle()
        }
    }
}

private extension RenderTextureLifecycleAction {
    var isTransient: Bool {
        self == .reuseTransient || self == .allocateTransient
    }
}

extension HarbethIO where Dest == MTLTexture {
    func encodeRenderProgram(_ program: RenderExecutionProgram, commandBuffer: MTLCommandBuffer) throws -> EncodedTextureProgram {
        guard program.sourceFilterFingerprint == filters.chainRecipe.fingerprint,
              program.diagnostics.inputSize == C7Size(texture: element) else {
            throw HarbethError.configurationInvalid(
                "RenderExecutionProgram does not match the HarbethIO input or filter chain."
            )
        }
        guard program.steps.isEmpty == false else {
            return EncodedTextureProgram(output: element, allocatedTextures: [])
        }

        prepareTextureLifecycle(for: program.plan, inputPixelFormat: element.pixelFormat)
        let rendering: RawTextureRendering
        if shouldUseDoubleBuffer(input: element, program: program, minimumFilterCount: 2) {
            rendering = try doubleBuffering(input: element, program: program, commandBuffer: commandBuffer)
        } else {
            rendering = try singleBuffer(input: element, program: program, commandBuffer: commandBuffer)
        }
        return EncodedTextureProgram(output: rendering.output, allocatedTextures: rendering.failureRecycling)
    }

    /// 把已编译的线性程序编码进调用方命令缓冲区但不提交，供上层配方维持单次 GPU 提交。
    func encodeManagedRenderProgram(_ program: RenderExecutionProgram, commandBuffer: MTLCommandBuffer) throws -> EncodedManagedTextureProgram {
        guard program.sourceFilterFingerprint == filters.chainRecipe.fingerprint,
              program.diagnostics.inputSize == C7Size(texture: element) else {
            throw HarbethError.configurationInvalid(
                "RenderExecutionProgram does not match the managed HarbethIO input or filter chain."
            )
        }
        guard program.steps.isEmpty == false else {
            return EncodedManagedTextureProgram(result: ManagedTextureResult(texture: element, lease: nil), producedLeases: [])
        }
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: element.pixelFormat)
        let managed: (result: ManagedTextureResult, intermediateLeases: [TextureLease])
        if shouldUseDoubleBuffer(input: element, program: program, minimumFilterCount: 2) {
            managed = try doubleBufferingManaged(input: element, program: program, commandBuffer: commandBuffer)
        } else {
            managed = try singleBufferManaged(input: element, program: program, commandBuffer: commandBuffer)
        }
        var leases = managed.intermediateLeases
        if let finalLease = managed.result.lease, leases.contains(where: { $0 === finalLease }) == false {
            leases.append(finalLease)
        }
        return EncodedManagedTextureProgram(result: managed.result, producedLeases: leases)
    }

    /// Starts a texture render task and returns a GPU task handle for status observation.
    ///
    /// This API is for advanced texture-first callers that need command-buffer status,
    /// completion observation, or explicit waiting without changing the existing
    /// `output()` and `transmitOutput(...)` behavior.
    func startCompiledRenderTextureTask(program: RenderExecutionProgram) throws -> RenderTask<MTLTexture> {
        guard program.sourceFilterFingerprint == filters.chainRecipe.fingerprint,
              program.diagnostics.inputSize == C7Size(texture: element) else {
            throw HarbethError.configurationInvalid(
                "RenderExecutionProgram does not match the HarbethIO input or filter chain."
            )
        }
        if program.steps.isEmpty {
            return .completed(identifier: identifier, output: element, diagnostics: program.diagnostics)
        }
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: element.pixelFormat)
        let commandBuffer = try makeCommandBuffer(for: nil)
        do {
            let rendering: RawTextureRendering
            if shouldUseDoubleBuffer(input: element, program: program, minimumFilterCount: 1) {
                rendering = try doubleBuffering(input: element, program: program, commandBuffer: commandBuffer)
            } else {
                rendering = try singleBuffer(input: element, program: program, commandBuffer: commandBuffer)
            }
            let cleanupState = HarbethUncheckedTransfer(
                value: (commandBuffer: commandBuffer, rendering: rendering)
            )
            let task = RenderTask(
                identifier: identifier,
                commandBuffer: commandBuffer,
                output: rendering.output,
                diagnostics: program.diagnostics,
                cleanup: {
                    let recycling = cleanupState.value.commandBuffer.status == .completed
                        ? cleanupState.value.rendering.successRecycling
                        : cleanupState.value.rendering.failureRecycling
                    self.recycleRawTextures(recycling)
                    HarbethContext.shared.recycleCommandBuffer(cleanupState.value.commandBuffer)
                }
            )
            commandBuffer.commit()
            return task
        } catch {
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            throw error
        }
    }

    func renderManagedTexture() throws -> ManagedTextureResult {
        if filters.isEmpty {
            return ManagedTextureResult(texture: element, lease: nil)
        }
        let program = makeRenderProgram(input: element)
        return try renderManagedTexture(program: program)
    }

    func renderManagedTexture(program: RenderExecutionProgram) throws -> ManagedTextureResult {
        guard program.sourceFilterFingerprint == filters.chainRecipe.fingerprint,
              program.diagnostics.inputSize == C7Size(texture: element) else {
            throw HarbethError.configurationInvalid(
                "RenderExecutionProgram does not match the managed HarbethIO input or filter chain."
            )
        }
        guard program.steps.isEmpty == false else {
            return ManagedTextureResult(texture: element, lease: nil)
        }
        switch groupStrategy(for: program.plan) {
        case .batched:
            return try processManagedBatchedFilters(input: element, program: program)
        case .interleaved:
            return try processManagedInterleavedFilters(input: element, program: program)
        }
    }

    @discardableResult
    func transmitManagedTexture(complete: @escaping @Sendable (Result<ManagedTextureResult, HarbethError>) -> Void) -> RenderSubmissionHandle {
        if filters.isEmpty {
            complete(.success(ManagedTextureResult(texture: element, lease: nil)))
            return completedSubmissionHandle()
        }
        let program = makeRenderProgram(input: element)
        let operationState = HarbethUncheckedTransfer(value: (io: self, program: program))
        return HarbethContext.shared.submitRenderOperation(
            sourceIdentifier: identifier,
            policy: submissionPolicy,
            execute: { submission in
                let io = operationState.value.io
                let program = operationState.value.program
                io.transmitManagedTexture(program: program, submission: submission) { result in
                    switch result {
                    case .success(let output):
                        if submission.deliver({ complete(.success(output)) }) == false {
                            output.lease?.release()
                        }
                    case .failure(let error):
                        submission.deliver { complete(.failure(error)) }
                    }
                }
            },
            onDiscard: { _ in complete(.failure(.renderableTaskCancelled)) }
        )
    }

    func transmitManagedTexture(program: RenderExecutionProgram, submission: RenderSubmissionContext, complete: @escaping @Sendable (Result<ManagedTextureResult, HarbethError>) -> Void) {
        guard let commandBuffer = submission.makeCommandBuffer() else {
            if submission.isActive {
                complete(.failure(.commandBuffer))
            }
            return
        }
        let encoded: EncodedManagedTextureProgram
        do {
            encoded = try encodeManagedRenderProgram(program, commandBuffer: commandBuffer)
        } catch {
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            complete(.failure(HarbethError.toHarbethError(error)))
            return
        }

        guard submission.claimCommit() else {
            encoded.releaseAll()
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            return
        }
        encoded.retainUntilCompleted(by: commandBuffer)
        let commandBufferTransfer = HarbethUncheckedTransfer(value: commandBuffer)

        if transmitOutputRealTimeCommit {
            commandBuffer.addCompletedHandler { _ in encoded.releaseIntermediates() }
            commandBuffer.realTimeCommit(identifier: identifier) {
                complete(.success(encoded.result))
            }
            DispatchQueue.global().async {
                commandBufferTransfer.value.waitUntilCompleted()
                HarbethContext.shared.recycleCommandBuffer(commandBufferTransfer.value)
            }
        } else {
            commandBuffer.asyncCommit(identifier: identifier) { callbackResult in
                switch callbackResult {
                case .success:
                    encoded.releaseIntermediates()
                    HarbethContext.shared.recycleCommandBuffer(commandBufferTransfer.value)
                    complete(.success(encoded.result))
                case .failure(let error):
                    encoded.releaseAll()
                    HarbethContext.shared.recycleCommandBuffer(commandBufferTransfer.value)
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            }
        }
    }

    private func processManagedBatchedFilters(input: MTLTexture, program: RenderExecutionProgram) throws -> ManagedTextureResult {
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: input.pixelFormat)
        let commandBuffer = try makeCommandBuffer(for: nil)
        let managed: (result: ManagedTextureResult, intermediateLeases: [TextureLease])
        do {
            if shouldUseDoubleBuffer(input: input, program: program, minimumFilterCount: 1) {
                managed = try doubleBufferingManaged(input: input, program: program, commandBuffer: commandBuffer)
            } else {
                managed = try singleBufferManaged(input: input, program: program, commandBuffer: commandBuffer)
            }
        } catch {
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            throw error
        }
        do {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
            managed.intermediateLeases.forEach { $0.release() }
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            return managed.result
        } catch {
            managed.intermediateLeases.forEach { $0.release() }
            managed.result.lease?.release()
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            throw error
        }
    }

    private func processManagedInterleavedFilters(input: MTLTexture, program: RenderExecutionProgram) throws -> ManagedTextureResult {
        prepareTextureLifecycle(for: program.plan, inputPixelFormat: input.pixelFormat)
        var currentTexture = input
        var currentLease: TextureLease?
        for step in program.steps {
            let commandBuffer: MTLCommandBuffer
            do {
                commandBuffer = try makeCommandBuffer(for: nil)
            } catch {
                currentLease?.release()
                throw error
            }
            let stage: ManagedTextureResult
            do {
                stage = try textureIOManaged(input: currentTexture, filter: step.filter, for: commandBuffer)
            } catch {
                currentLease?.release()
                HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                throw error
            }
            do {
                try commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
                HarbethContext.shared.recycleCommandBuffer(commandBuffer)
            } catch {
                stage.lease?.release()
                currentLease?.release()
                HarbethContext.shared.recycleCommandBuffer(commandBuffer)
                throw error
            }

            if let previousLease = currentLease, previousLease.texture !== stage.texture {
                previousLease.release()
                currentLease = nil
            }
            if let producedLease = stage.lease {
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

    private func singleBufferManaged(input: MTLTexture, program: RenderExecutionProgram, commandBuffer: MTLCommandBuffer) throws -> (ManagedTextureResult, [TextureLease]) {
        var currentTexture = input
        var producedLeases: [TextureLease] = []
        do {
            for step in program.steps {
                let stage = try textureIOManaged(input: currentTexture, filter: step.filter, for: commandBuffer)
                if let lease = stage.lease {
                    producedLeases.append(lease)
                }
                currentTexture = stage.texture
            }
        } catch {
            producedLeases.forEach { $0.release() }
            throw error
        }

        let finalLease = producedLeases.last(where: { $0.texture === currentTexture })
        let intermediateLeases = producedLeases.filter { lease in
            lease.texture !== currentTexture && lease.texture !== input
        }
        return (ManagedTextureResult(texture: currentTexture, lease: finalLease), intermediateLeases)
    }

    private func doubleBufferingManaged(input: MTLTexture, program: RenderExecutionProgram, commandBuffer: MTLCommandBuffer) throws -> (ManagedTextureResult, [TextureLease]) {
        let filters = program.filters
        let width = input.width
        let height = input.height
        let pixelFormat = input.pixelFormat
        let requiresRenderTarget = filters.contains { filter in
            if case .render = filter.modifier { return true }
            return false
        }
        if requiresRenderTarget == false {
            prewarmDoubleBufferReservations(
                for: program.plan,
                fallbackSize: C7Size(width: width, height: height),
                inputPixelFormat: pixelFormat
            )
        }
        let doubleBufferUsage: MTLTextureUsage = requiresRenderTarget
            ? [.shaderRead, .shaderWrite, .renderTarget]
            : [.shaderRead, .shaderWrite]
        let leaseA = try TextureLoader.makeTextureLease(
            width: width,
            height: height,
            options: [
                .texturePixelFormat: pixelFormat,
                .textureUsage: doubleBufferUsage
            ],
            identifier: identifier
        )
        let leaseB: TextureLease
        do {
            leaseB = try TextureLoader.makeTextureLease(
                width: width,
                height: height,
                options: [
                    .texturePixelFormat: pixelFormat,
                    .textureUsage: doubleBufferUsage
                ],
                identifier: identifier
            )
        } catch {
            leaseA.release()
            throw error
        }

        var currentInput = input
        var currentOutput = leaseA.texture

        do {
            for (index, filter) in filters.enumerated() {
                if let filter = filter as? C7FilterPipelineProtocol {
                    currentInput = try FilterPipelineExecutor.apply(
                        filter: filter,
                        source: currentInput,
                        destination: currentOutput,
                        commandBuffer: commandBuffer
                    )
                    if index < filters.count - 1 {
                        currentOutput = currentOutput === leaseA.texture ? leaseB.texture : leaseA.texture
                    }
                    continue
                }
                let preparedInput = try filter.combinationBegin(
                    for: commandBuffer,
                    source: currentInput,
                    dest: currentOutput
                )
                let outputTexture = try filter.apply(
                    form: preparedInput,
                    to: currentOutput,
                    for: commandBuffer,
                    complete: nil
                )
                currentInput = try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: currentInput)
                if index < filters.count - 1 {
                    currentOutput = currentOutput === leaseA.texture ? leaseB.texture : leaseA.texture
                }
            }
        } catch {
            leaseA.release()
            leaseB.release()
            throw error
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

        return (ManagedTextureResult(texture: currentInput, lease: finalLease), intermediateLeases)
    }
}
