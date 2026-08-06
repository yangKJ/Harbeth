//
//  HarbethIOExecution.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import MetalKit

struct HarbethUncheckedTransfer<Value>: @unchecked Sendable {
    let value: Value
}

enum HarbethIOTransmitOutputDelivery: Sendable, Equatable {
    case commandBufferScheduled
    case gpuCompleted
}

enum HarbethIOExecutionStrategy {
    case batched
    case interleaved
}

// MARK: - Internal Texture Execution Values

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

struct RawTextureStage {
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

// MARK: - Internal Output Contract Planning

extension HarbethIO {

    func resolvedOutputColorSpace(inputSize: C7Size, outputColorSpace: ImageColorSpaceContract? = nil) -> ImageColorSpaceContract {
        outputColorSpace ?? filters.reduce(.preserveInput) { current, filter in
            let declared = filter.kernelDescriptor(inputSize: inputSize).outputContract.colorSpace
            return declared.preservesInput ? current : declared
        }
    }

    func makeEffectiveFilters(inputSize: C7Size, derivative: ImageDerivativeSpec) -> [C7FilterProtocol] {
        let baseOutputSize = filters.reduce(inputSize) { size, filter in filter.resize(input: size) }
        let targetOutputSize = derivative.resolvedOutputSize(for: baseOutputSize)
        guard targetOutputSize != baseOutputSize else { return filters }
        return filters + [C7Resize(width: Float(targetOutputSize.width), height: Float(targetOutputSize.height))]
    }
}

// MARK: - Internal Source Adaptation

extension HarbethIO {
    func makeImageSource() throws -> ImageSource {
        switch element {
        case let texture as MTLTexture:
            return .texture(texture)
        case let image as C7Image:
            return .image(image)
        case let image as CIImage:
            return .ciImage(image)
        case let data as Data:
            return .data(data)
        case let url as URL:
            return .asset(ImageAsset(storage: .url(url)))
        case let asset as ImageAsset:
            return .asset(asset)
        case let value where CFGetTypeID(value as CFTypeRef) == CGImage.typeID:
            return .cgImage(value as! CGImage)
        case let value where CFGetTypeID(value as CFTypeRef) == CVPixelBufferGetTypeID():
            return .pixelBuffer(value as! CVPixelBuffer)
        case let value where CFGetTypeID(value as CFTypeRef) == CMSampleBufferGetTypeID():
            return .sampleBuffer(value as! CMSampleBuffer)
        default:
            throw HarbethError.source2Texture
        }
    }
}

// MARK: - Internal Profile Configuration and Materialization

extension HarbethIO {
    func configured(for profile: RenderProfile) -> Self {
        var copy = self
        copy.renderProfile = profile
        return copy
    }

    // MARK: - Internal Texture and Pixel Buffer Materialization

    /// texture-first 同步输出，不执行 CPU 读回。
    func renderTexture(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        guard context.effectiveFilters.isEmpty == false else {
            return context.sourceTexture
        }
        return try HarbethIO<MTLTexture>(element: context.sourceTexture, filters: context.effectiveFilters)
            .configured(for: profile)
            .output()
    }

    /// 将单帧渲染结果输出为新的 `CVPixelBuffer`，不修改输入 pixel buffer。
    func renderPixelBuffer(profile: RenderProfile = .stablePreview,
                           derivative: ImageDerivativeSpec? = nil,
                           pool: PixelBufferPool? = nil,
                           pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
                           outputPixelFormat: PixelFormatContract = .preserveInput,
                           outputColorSpace: ImageColorSpaceContract? = nil) throws -> CVPixelBuffer {
        let result = try renderTextureForPixelBuffer(
            profile: profile,
            derivative: derivative,
            requestedPixelFormatType: pixelFormatType,
            outputPixelFormat: outputPixelFormat,
            outputColorSpace: outputColorSpace
        )
        let texture = result.texture
        let resolvedPixelFormatType = try resolvePixelBufferFormatType(
            requestedPixelFormatType: pixelFormatType,
            outputPixelFormat: outputPixelFormat,
            renderedTexture: texture
        )
        let outputPool = try pool ?? PixelBufferPool(
            width: texture.width,
            height: texture.height,
            pixelFormatType: resolvedPixelFormatType
        )
        let pixelBuffer = try outputPool.makePixelBuffer()
        if let compatibilityError = pixelBuffer.c7.textureCopyCompatibilityError(for: texture) {
            throw compatibilityError
        }
        guard pixelBuffer.c7.copyToPixelBuffer(with: texture) else {
            throw HarbethError.pixelBufferCopyFailed
        }
        copySourceImageBufferAttachmentsIfNeeded(to: pixelBuffer)
        pixelBuffer.c7.setColorSpaceAttachments(result.outputColorSpace)
        return pixelBuffer
    }

}

// MARK: - Internal Pixel Buffer Support

private extension HarbethIO {
    private func resolvedExecutionContext(profile: RenderProfile, derivative: ImageDerivativeSpec? = nil) throws -> (
        sourceObject: ImageSource,
        sourceTexture: MTLTexture,
        effectiveDerivative: ImageDerivativeSpec,
        effectiveFilters: [C7FilterProtocol]
    ) {
        let sourceObject = try makeImageSource()
        let sourceTexture = try sourceObject.makeTexture()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let effectiveFilters = makeEffectiveFilters(
            inputSize: C7Size(texture: sourceTexture),
            derivative: effectiveDerivative
        )
        return (sourceObject, sourceTexture, effectiveDerivative, effectiveFilters)
    }

    private func renderTextureForPixelBuffer(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        requestedPixelFormatType: OSType,
        outputPixelFormat: PixelFormatContract,
        outputColorSpace: ImageColorSpaceContract? = nil
    ) throws -> (texture: MTLTexture, outputColorSpace: ImageColorSpaceContract) {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        var effectiveFilters = context.effectiveFilters
        let targetPixelFormat: MTLPixelFormat? = {
            if outputPixelFormat.preservesInput {
                switch requestedPixelFormatType {
                case kCVPixelFormatType_32BGRA:
                    return .bgra8Unorm
                case kCVPixelFormatType_32RGBA, kCVPixelFormatType_32ARGB:
                    return .rgba8Unorm
                case kCVPixelFormatType_64RGBAHalf:
                    return .rgba16Float
                case kCVPixelFormatType_OneComponent8:
                    return .r8Unorm
                default:
                    return nil
                }
            }
            return outputPixelFormat.metalPixelFormat
        }()
        if effectiveFilters.isEmpty, let targetPixelFormat, context.sourceTexture.pixelFormat != targetPixelFormat {
            effectiveFilters = [C7Brightness(brightness: 0)]
        }
        guard effectiveFilters.isEmpty == false else {
            return (context.sourceTexture, outputColorSpace ?? .preserveInput)
        }
        var io = HarbethIO<MTLTexture>(element: context.sourceTexture, filters: effectiveFilters)
            .configured(for: profile)
        if let targetPixelFormat {
            io.bufferPixelFormat = targetPixelFormat
        }
        let outputColorSpace = io.resolvedOutputColorSpace(
            inputSize: C7Size(texture: context.sourceTexture),
            outputColorSpace: outputColorSpace
        )
        let texture = try io.output()
        return (texture, outputColorSpace)
    }

    private func resolvePixelBufferFormatType(requestedPixelFormatType: OSType, outputPixelFormat: PixelFormatContract, renderedTexture: MTLTexture) throws -> OSType {
        if outputPixelFormat.preservesInput {
            return requestedPixelFormatType
        }
        guard let targetPixelFormat = outputPixelFormat.metalPixelFormat else {
            throw HarbethError.configurationInvalid(
                "Pixel buffer output pixel format contract must resolve to a Metal pixel format."
            )
        }
        guard let resolvedType = RenderPixelBufferDescriptor.pixelFormatType(for: targetPixelFormat) else {
            throw HarbethError.configurationInvalid(
                "Pixel buffer output does not support Metal pixel format \(targetPixelFormat)."
            )
        }
        if renderedTexture.pixelFormat != targetPixelFormat {
            throw HarbethError.configurationInvalid(
                "Rendered texture pixel format mismatch for pixel buffer output. Texture pixelFormat=\(renderedTexture.pixelFormat), expected \(targetPixelFormat)."
            )
        }
        return resolvedType
    }

    private func copySourceImageBufferAttachmentsIfNeeded(to pixelBuffer: CVPixelBuffer) {
        switch element {
        case let source where CFGetTypeID(source as CFTypeRef) == CVPixelBufferGetTypeID():
            pixelBuffer.c7.copyAttachments(from: source as! CVPixelBuffer)
        case let source where CFGetTypeID(source as CFTypeRef) == CMSampleBufferGetTypeID():
            guard let imageBuffer = CMSampleBufferGetImageBuffer(source as! CMSampleBuffer) else {
                return
            }
            pixelBuffer.c7.copyAttachments(from: imageBuffer)
        default:
            break
        }
    }
}

// MARK: - Internal Texture Lifecycle Support

extension RenderTextureLifecycleAction {
    var isTransient: Bool {
        self == .reuseTransient || self == .allocateTransient
    }
}

// MARK: - Internal Texture-Only Execution Primitives

extension HarbethIO where Dest == MTLTexture {
    // MARK: - Program Encoding

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

    // MARK: - Render Task Delivery

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

    // MARK: - Managed Texture Delivery

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
        let commandBufferState = HarbethUncheckedTransfer(value: commandBuffer)
        switch resolvedTransmitOutputDelivery(requiresCompletedGPUWork: false) {
        case .commandBufferScheduled:
            commandBuffer.addCompletedHandler { _ in encoded.releaseIntermediates() }
            commandBuffer.realTimeCommit(identifier: identifier) {
                complete(.success(encoded.result))
            }
        case .gpuCompleted:
            commandBuffer.asyncCommit(identifier: identifier) { callbackResult in
                switch callbackResult {
                case .success:
                    encoded.releaseIntermediates()
                    HarbethContext.shared.recycleCommandBuffer(commandBufferState.value)
                    complete(.success(encoded.result))
                case .failure(let error):
                    encoded.releaseAll()
                    HarbethContext.shared.recycleCommandBuffer(commandBufferState.value)
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
        let pixelFormat = resolvedBufferPixelFormat(sourcePixelFormat: input.pixelFormat)
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
