//
//  ImageNode.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal
import CoreGraphics
import CoreImage
import CoreVideo
import CoreMedia

protocol ImagePromise {
    var compilationSource: RenderCompilationSource { get }
    func makeTexture(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> MTLTexture
    func makeDiagnostics(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> RenderPlanDiagnostics
}

private final class OutputContractCacheEntry {
    weak var sourceTexture: AnyObject?
    let outputTexture: MTLTexture

    init(sourceTexture: MTLTexture, outputTexture: MTLTexture) {
        self.sourceTexture = sourceTexture as AnyObject
        self.outputTexture = outputTexture
    }
}

/// 同一次请求共享源物化结果；独立请求之间不共享可变纹理快照。
final class ImageNodeSourcePreparation {
    private let lock = NSLock()
    private var textures: [String: MTLTexture] = [:]

    func texture(for source: ImageSource) throws -> MTLTexture {
        switch source {
        case .texture(let texture): return texture
        case .pixelBuffer, .sampleBuffer:
            // 视频帧已有尺寸提示，规划不需要物化，直接保留既有桥接路径。
            return try source.makeTexture()
        default: break
        }
        return try lock.withLock {
            let key = source.resolutionFingerprint
            if let texture = textures[key] { return texture }
            let texture = try source.makeTexture()
            textures[key] = texture
            return texture
        }
    }
}

/// 单次 ImageNode 渲染使用的内部执行快照。
///
/// 公开入口仍然只有 ImageNode；这个值只把 plan、recipe、source 与实际执行绑定在一起，
/// 防止 frame/request 在执行后重新编译另一份 diagnostics。
private struct PreparedImageNodeExecution: @unchecked Sendable {
    let profile: RenderProfile
    let derivative: ImageDerivativeSpec
    let diagnostics: RenderPlanDiagnostics
    let renderRecipe: RenderRecipe
    let primarySource: ImageSource
    let executionFingerprint: String
    let renderTextureClosure: () throws -> MTLTexture
    let renderManagedTextureClosure: (() throws -> ManagedTextureResult)?
    let transmitManagedTextureClosure: ((RenderSubmissionContext, @escaping @Sendable (Result<ManagedTextureResult, HarbethError>) -> Void) -> Void)?

    func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }

    func renderManagedTexture() throws -> ManagedTextureResult {
        if let renderManagedTextureClosure {
            return try renderManagedTextureClosure()
        }
        return ManagedTextureResult(texture: try renderTexture(), lease: nil)
    }
}

private struct ImageNodeRenderPlanPreparation {
    let node: ImageNode
    let derivative: ImageDerivativeSpec?
    let samplerDescriptor: ImageSamplerDescriptor
    let cacheKey: String
    let optimization: ImageGraphOptimizationResult
}

private struct ImageNodeExecutionPreparation {
    let node: ImageNode
    let derivative: ImageDerivativeSpec
    let samplerDescriptor: ImageSamplerDescriptor
    let plan: RenderPlan
    let primarySource: ImageSource
    let storage: ImageNodeStorage
}

private struct PreparedImageNodeAttachmentRoute: @unchecked Sendable {
    let inputExecution: PreparedImageNodeExecution
    let filter: any RenderProtocol
    let validateInput: (MTLTexture) throws -> Void

    func renderAttachmentSet(identifier: String) throws -> RenderedAttachmentSet {
        let texture = try inputExecution.renderTexture()
        try validateInput(texture)
        return try filter.renderAttachmentSet(from: texture, identifier: identifier)
    }

    func renderAnalysisBundle(
        identifier: String,
        bins: Int,
        histogramHeight: Int,
        region: MTLRegion?,
        preferredMethod: TextureHistogramComputationMethod
    ) throws -> RenderedAttachmentAnalysisBundle {
        let texture = try inputExecution.renderTexture()
        try validateInput(texture)
        return try filter.renderAttachmentAnalysisBundle(
            from: texture,
            identifier: identifier,
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    func renderAnalysisBundle(
        identifier: String,
        bins: Int,
        histogramHeight: Int,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod
    ) throws -> RenderedAttachmentAnalysisBundle {
        let texture = try inputExecution.renderTexture()
        try validateInput(texture)
        return try filter.renderAttachmentAnalysisBundle(
            from: texture,
            identifier: identifier,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }
}

indirect enum ImageNodeStorage {
    case source(ImageSource)
    case filters(input: ImageNode, filters: [C7FilterProtocol])
    case kernel(input: ImageNode, descriptor: KernelDescriptor, filter: C7FilterProtocol)
    case edit(input: ImageNode, recipe: EditRecipe, mode: EditRecipeMode)
    case transition(TransitionRecipe)
    case layerComposite(LayerCompositeRecipe)
    case cachePolicy(input: ImageNode, policy: ImageCachePolicy)
    case samplerDescriptor(input: ImageNode, descriptor: ImageSamplerDescriptor)
}

public struct ImageNode {
    let storage: ImageNodeStorage

    init(storage: ImageNodeStorage) {
        self.storage = storage
    }

    static func filters(input: ImageNode, filters: [C7FilterProtocol]) -> ImageNode {
        ImageNode(storage: .filters(input: input, filters: filters))
    }

    static func kernel(input: ImageNode, descriptor: KernelDescriptor, filter: C7FilterProtocol) -> ImageNode {
        ImageNode(storage: .kernel(input: input, descriptor: descriptor, filter: filter))
    }

    func applying(_ invocation: KernelInvocation) -> ImageNode {
        ImageNode(storage: .kernel(input: self, descriptor: invocation.descriptor, filter: invocation.executableFilter))
    }
}

extension ImageNode {
    public static func source(_ source: ImageSource) -> ImageNode {
        ImageNode(storage: .source(source))
    }

    public static func recipe(source: ImageSource, recipe: EditRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        ImageNode.source(source).editing(recipe, mode: mode)
    }

    public static func layerComposite(_ recipe: LayerCompositeRecipe) -> ImageNode {
        ImageNode(storage: .layerComposite(recipe))
    }

    public static func texture(_ texture: MTLTexture) -> ImageNode {
        .source(ImageSource.texture(texture))
    }

    public static func image(_ image: C7Image) -> ImageNode {
        .source(ImageSource.image(image))
    }

    public static func cgImage(_ image: CGImage) -> ImageNode {
        .source(ImageSource.cgImage(image))
    }

    public static func ciImage(_ image: CIImage) -> ImageNode {
        .source(ImageSource.ciImage(image))
    }

    public static func pixelBuffer(_ pixelBuffer: CVPixelBuffer) -> ImageNode {
        .source(ImageSource.pixelBuffer(pixelBuffer))
    }

    public static func sampleBuffer(_ sampleBuffer: CMSampleBuffer) -> ImageNode {
        .source(ImageSource.sampleBuffer(sampleBuffer))
    }

    public static func data(_ data: Data) -> ImageNode {
        .source(ImageSource.data(data))
    }

    public static func asset(_ asset: ImageAsset) -> ImageNode {
        .source(ImageSource.asset(asset))
    }

    public func withCachePolicy(_ policy: ImageCachePolicy) -> ImageNode {
        ImageNode(storage: .cachePolicy(input: self, policy: policy))
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> ImageNode {
        ImageNode(storage: .samplerDescriptor(input: self, descriptor: descriptor))
    }

    public func applying(_ filter: C7FilterProtocol) -> ImageNode {
        ImageNode(storage: .filters(input: self, filters: [filter]))
    }

    public func applying(filters: [C7FilterProtocol]) -> ImageNode {
        guard filters.isEmpty == false else { return self }
        return ImageNode(storage: .filters(input: self, filters: filters))
    }

    public func applyingWithContract(_ filter: C7FilterProtocol, inputSize: C7Size? = nil) -> ImageNode {
        let descriptor = filter.kernelDescriptor(inputSize: inputSize)
        let invocation = descriptor.makeInvocation(filter: filter, inputSize: inputSize)
        return applying(invocation)
    }

    public func applying(pluginOutput: PluginOutput, mode: EditRecipeMode = .preview) throws -> ImageNode {
        switch pluginOutput {
        case .texture, .image, .cgImage, .ciImage, .pixelBuffer, .sampleBuffer:
            return ImageNode.source(try pluginOutput.makeImageSource())
        case .filters(let filters):
            return applying(filters: filters)
        case .editRecipe(let recipe):
            return editing(recipe, mode: mode)
        case .localEffect(let localEffect):
            return applying(localEffect: localEffect, mode: mode)
        case .layerComposite(let recipe):
            return ImageNode.layerComposite(recipe)
        }
    }

    public func applying<P: Plugin>(
        plugin: P,
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        mode: EditRecipeMode = .preview
    ) throws -> ImageNode {
        let frame = try makeFrame(profile: profile, derivative: derivative)
        let context = PluginContext(
            profile: profile,
            identifier: plugin.pluginIdentifier,
            metadata: [
                "pluginIdentifier": plugin.pluginIdentifier,
                "pluginBoundaryKind": plugin.capability.kind.rawValue,
            ]
        )
        let output = try plugin.makeOutput(frame: frame, context: context)
        return try applying(pluginOutput: output, mode: mode)
    }

    private func prepareExecution(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        executionIdentifier: String?,
        samplerDescriptorOverride: ImageSamplerDescriptor? = nil,
        sources: ImageNodeSourcePreparation = ImageNodeSourcePreparation()
    ) throws -> PreparedImageNodeExecution {
        var preparations: [ImageNodeExecutionPreparation] = []
        var node = self
        var nextDerivative = derivative
        var samplerOverride = samplerDescriptorOverride

        // 先沿输入链收集与原递归相同的规划快照，再从来源向输出装配执行闭包。
        // 大型装配栈帧不再随蒙版和 wrapper 深度叠加，源物化仍由本次请求唯一持有。
        preparationLoop: while true {
            let preparation = try node.prepareExecutionStep(
                profile: profile,
                derivative: nextDerivative,
                samplerDescriptorOverride: samplerOverride,
                sources: sources
            )
            preparations.append(preparation)
            switch preparation.storage {
            case .filters(let input, _), .kernel(let input, _, _), .edit(let input, _, _):
                node = input
                nextDerivative = profile.defaultDerivativeSpec
                samplerOverride = preparation.samplerDescriptor
            case .cachePolicy(let input, _):
                node = input
                nextDerivative = preparation.derivative
                samplerOverride = preparation.samplerDescriptor
            case .samplerDescriptor(let input, let descriptor):
                node = input
                nextDerivative = preparation.derivative
                samplerOverride = descriptor
            case .source, .transition, .layerComposite:
                break preparationLoop
            }
        }

        var preparedInput: PreparedImageNodeExecution?
        for preparation in preparations.reversed() {
            preparedInput = try preparation.node.assembleExecution(
                from: preparation,
                preparedInput: preparedInput,
                profile: profile,
                executionIdentifier: executionIdentifier,
                sources: sources
            )
        }
        guard let preparedInput else {
            preconditionFailure("执行准备至少包含一个来源节点。")
        }
        return preparedInput
    }

    private func prepareExecutionStep(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        samplerDescriptorOverride: ImageSamplerDescriptor?,
        sources: ImageNodeSourcePreparation
    ) throws -> ImageNodeExecutionPreparation {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let activeSamplerDescriptor = samplerDescriptorOverride ?? resolvedSamplerDescriptor
        let plan = try makeRenderPlan(
            profile: profile,
            derivative: effectiveDerivative,
            samplerDescriptorOverride: activeSamplerDescriptor,
            sources: sources
        )
        let primarySource = try resolvedPrimarySource()
        let executionStorage: ImageNodeStorage
        if case .filters = storage {
            let route = flattenedFilterRoute()
            executionStorage = .filters(input: route.input, filters: route.filters)
        } else {
            executionStorage = storage
        }
        return ImageNodeExecutionPreparation(
            node: self,
            derivative: effectiveDerivative,
            samplerDescriptor: activeSamplerDescriptor,
            plan: plan,
            primarySource: primarySource,
            storage: executionStorage
        )
    }

    private func assembleExecution(
        from preparation: ImageNodeExecutionPreparation,
        preparedInput: PreparedImageNodeExecution?,
        profile: RenderProfile,
        executionIdentifier: String?,
        sources: ImageNodeSourcePreparation
    ) throws -> PreparedImageNodeExecution {
        let effectiveDerivative = preparation.derivative
        let activeSamplerDescriptor = preparation.samplerDescriptor
        let plan = preparation.plan
        let diagnostics = plan.diagnostics
        let primarySource = preparation.primarySource
        let renderRecipe: RenderRecipe
        let renderTextureClosure: () throws -> MTLTexture
        var renderManagedTextureClosure: (() throws -> ManagedTextureResult)? = nil
        var transmitManagedTextureClosure: ((RenderSubmissionContext, @escaping @Sendable (Result<ManagedTextureResult, HarbethError>) -> Void) -> Void)? = nil
        let executionFingerprint: String

        switch preparation.storage {
        case .source(let source):
            renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative, preparedPlan: plan, sources: sources)
            renderTextureClosure = {
                if let io = try source.planeAwareIO(filters: [], profile: profile, identifier: executionIdentifier ?? "ImageNode.Source",
                                                   derivative: effectiveDerivative) { return try io.output() }
                let texture = try sources.texture(for: source)
                return try ImageNode.applyDerivativeResize(
                    texture,
                    derivative: effectiveDerivative,
                    profile: profile,
                    identifier: executionIdentifier
                )
            }
            executionFingerprint = [diagnostics.graphFingerprint, source.descriptor.fingerprint].joined(separator: "|")

        case .filters(let input, let filters):
            guard let preparedInput else {
                preconditionFailure("上游执行快照必须先于当前节点准备。")
            }
            renderRecipe = preparedInput.renderRecipe.appending(
                filterDescriptors: filters.map { $0.recipeDescriptor.withSamplerContract(activeSamplerDescriptor) },
                derivative: effectiveDerivative
            )
            let program = RenderExecutionCompiler.compile(
                filters: filters,
                inputSize: preparedInput.diagnostics.outputSize,
                profile: profile,
                derivative: effectiveDerivative,
                compilationSource: diagnostics.compilationSource,
                outputContract: diagnostics.outputContract,
                imageCachePolicy: diagnostics.imageCachePolicy,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: primarySource.descriptor,
                imageGraph: plan.imageGraph,
                graphOptimizationDecisions: diagnostics.graphOptimizationDecisions,
                preparedPlan: plan,
                inputAlphaType: preparedInput.diagnostics.outputAlphaType ?? primarySource.alphaType
            )
            renderTextureClosure = {
                if case .source(let source) = input.storage,
                   let io = try source.planeAwareIO(filters: program.filters, profile: profile, identifier: executionIdentifier ?? "ImageNode.PreparedFilters") {
                    return try io.output()
                }
                let inputTexture = try preparedInput.renderTexture()
                let io = HarbethIO<MTLTexture>(element: inputTexture, filters: filters, identifier: executionIdentifier ?? "ImageNode.PreparedFilters").configured(for: profile)
                return try io.executeRenderProgram(input: inputTexture, program: program)
            }
            if case .source(let source) = input.storage {
                renderManagedTextureClosure = {
                    if let io = try source.planeAwareIO(filters: program.filters, profile: profile, identifier: executionIdentifier ?? "ImageNode.PreparedFilters") {
                        return try io.renderManagedTexture()
                    }
                    let inputTexture = try sources.texture(for: source)
                    let io = HarbethIO<MTLTexture>(element: inputTexture, filters: filters, identifier: executionIdentifier ?? "ImageNode.PreparedFilters").configured(for: profile)
                    return try io.renderManagedTexture(program: program)
                }
                transmitManagedTextureClosure = { submission, complete in
                    do {
                        if var io = try source.planeAwareIO(filters: program.filters, profile: profile, identifier: executionIdentifier ?? "ImageNode.PreparedFilters") {
                            io.transmitOutputRealTimeCommit = false
                            io.transmitManagedTexture(program: io.makeRenderProgram(input: io.element), submission: submission, complete: complete)
                            return
                        }
                        let inputTexture = try sources.texture(for: source)
                        var io = HarbethIO<MTLTexture>(element: inputTexture, filters: filters, identifier: executionIdentifier ?? "ImageNode.PreparedFilters").configured(for: profile)
                        io.transmitOutputRealTimeCommit = false
                        io.transmitManagedTexture(program: program, submission: submission, complete: complete)
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                }
            }
            executionFingerprint = [
                diagnostics.graphFingerprint,
                preparedInput.executionFingerprint,
                program.fingerprint,
            ].joined(separator: "|")

        case .kernel(_, let descriptor, let filter):
            guard let preparedInput else {
                preconditionFailure("上游执行快照必须先于当前节点准备。")
            }
            renderRecipe = preparedInput.renderRecipe.appending(
                filterDescriptors: [filter.recipeDescriptor.withSamplerContract(activeSamplerDescriptor)],
                derivative: effectiveDerivative
            )
            let adaptedFilter = SamplerExecutionAdapter.adapt(
                filter: filter,
                samplerDescriptor: activeSamplerDescriptor
            )
            let sourceDerivative = ImageDerivativeSpec(
                name: "prepared-kernel-source",
                renderIntent: effectiveDerivative.renderIntent,
                sourceTier: effectiveDerivative.sourceTier,
                semantic: effectiveDerivative.semantic,
                outputSizePolicy: .source
            )
            let program = RenderExecutionCompiler.compile(
                filters: [adaptedFilter],
                inputSize: preparedInput.diagnostics.outputSize,
                profile: profile,
                derivative: sourceDerivative,
                compilationSource: diagnostics.compilationSource,
                outputContract: descriptor.outputContract,
                imageCachePolicy: diagnostics.imageCachePolicy,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: primarySource.descriptor,
                inputAlphaType: preparedInput.diagnostics.outputAlphaType ?? primarySource.alphaType
            )
            renderTextureClosure = {
                let inputTexture = try preparedInput.renderTexture()
                try descriptor.validateCompatibility(with: filter, inputSize: C7Size(texture: inputTexture))
                let io = HarbethIO<MTLTexture>(
                    element: inputTexture,
                    filters: [adaptedFilter],
                    identifier: executionIdentifier ?? "ImageNode.PreparedKernel"
                ).configured(for: profile)
                let rendered = try io.executeRenderProgram(input: inputTexture, program: program)
                let contracted = try ImageNode.applyOutputContractIfNeeded(
                    descriptor.outputContract,
                    to: rendered,
                    sourceColorSpace: descriptor.inputColorSpace,
                    sourceAlphaType: descriptor.outputContract.inputAlphaExpectation.expectedAlphaType,
                    profile: profile,
                    identifier: executionIdentifier
                )
                return try ImageNode.applyDerivativeResize(
                    contracted,
                    derivative: effectiveDerivative,
                    profile: profile,
                    identifier: executionIdentifier
                )
            }
            executionFingerprint = [
                diagnostics.graphFingerprint,
                preparedInput.executionFingerprint,
                program.fingerprint,
                descriptor.fingerprint,
            ].joined(separator: "|")

        case .edit(_, let recipe, let mode):
            guard let preparedInput else {
                preconditionFailure("上游执行快照必须先于当前节点准备。")
            }
            renderRecipe = try makeRenderRecipe(
                profile: profile,
                derivative: effectiveDerivative,
                preparedPlan: plan,
                sources: sources,
                preparedInputRecipe: preparedInput.renderRecipe
            )
            renderTextureClosure = {
                var inputTexture = try preparedInput.renderTexture()
                if (preparedInput.diagnostics.outputAlphaType ?? primarySource.alphaType) == .nonPremultiplied,
                   diagnostics.outputContract.inputAlphaExpectation == .premultiplied {
                    inputTexture = try HarbethIO(element: inputTexture, filter: C7PremultiplyAlpha()).configured(for: profile).output()
                }
                return try FrameRenderer(
                    source: .texture(inputTexture),
                    recipe: recipe,
                    mode: mode,
                    identifier: executionIdentifier ?? "ImageNode.PreparedEdit",
                    derivative: effectiveDerivative,
                    samplerDescriptor: activeSamplerDescriptor
                ).renderTexture()
            }
            executionFingerprint = [
                diagnostics.graphFingerprint,
                preparedInput.executionFingerprint,
                renderRecipe.fingerprint,
                "mode=\(mode)",
            ].joined(separator: "|")

        case .transition(let recipe):
            renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative, preparedPlan: plan, sources: sources)
            let renderer = FrameRenderer(
                transitionRecipe: recipe,
                profile: profile,
                derivative: effectiveDerivative,
                identifier: executionIdentifier ?? "ImageNode.PreparedTransition",
                samplerDescriptor: activeSamplerDescriptor
            )
            renderTextureClosure = { try renderer.renderTexture() }
            executionFingerprint = [diagnostics.graphFingerprint, renderRecipe.fingerprint].joined(separator: "|")

        case .layerComposite(let recipe):
            renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative, preparedPlan: plan, sources: sources)
            renderTextureClosure = {
                try recipe.makeTexture(
                    profile: profile,
                    derivative: effectiveDerivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    executionIdentifier: executionIdentifier ?? "ImageNode.PreparedLayerComposite"
                )
            }
            executionFingerprint = [diagnostics.graphFingerprint, recipe.fingerprint].joined(separator: "|")

        case .cachePolicy(_, let policy):
            guard let preparedInput else {
                preconditionFailure("上游执行快照必须先于当前节点准备。")
            }
            renderRecipe = preparedInput.renderRecipe.with(outputCachePolicy: policy)
            let cacheKey = resolutionFingerprint(profile: profile, derivative: effectiveDerivative)
            renderTextureClosure = {
                if policy == .persistent,
                   let cached = HarbethContext.shared.cachedResolvedTexture(for: cacheKey) {
                    return cached
                }
                let texture = try preparedInput.renderTexture()
                if policy == .persistent {
                    HarbethContext.shared.storeResolvedTexture(texture, for: cacheKey)
                }
                return texture
            }
            executionFingerprint = [diagnostics.graphFingerprint, preparedInput.executionFingerprint, "cache=\(policy.rawValue)"].joined(separator: "|")

        case .samplerDescriptor(_, let descriptor):
            guard let preparedInput else {
                preconditionFailure("上游执行快照必须先于当前节点准备。")
            }
            renderRecipe = preparedInput.renderRecipe
            renderTextureClosure = { try preparedInput.renderTexture() }
            executionFingerprint = [diagnostics.graphFingerprint, preparedInput.executionFingerprint, descriptor.fingerprint].joined(separator: "|")
        }

        return PreparedImageNodeExecution(
            profile: profile,
            derivative: effectiveDerivative,
            diagnostics: diagnostics,
            renderRecipe: renderRecipe,
            primarySource: primarySource,
            executionFingerprint: executionFingerprint,
            renderTextureClosure: renderTextureClosure,
            renderManagedTextureClosure: renderManagedTextureClosure,
            transmitManagedTextureClosure: transmitManagedTextureClosure
        )
    }

    public func makeFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:]
    ) throws -> RenderedFrame {
        let monitoringIdentifier = self.monitoringIdentifier
        let monitorEnabled = HarbethContext.shared.enablePerformanceMonitor
        if monitorEnabled { HarbethContext.shared.performanceMonitor.beginMonitoring(monitoringIdentifier) }
        defer {
            if monitorEnabled {
                HarbethContext.shared.performanceMonitor.endMonitoring(monitoringIdentifier)
            }
        }

        let prepared = try prepareExecution(
            profile: profile,
            derivative: derivative,
            executionIdentifier: monitoringIdentifier
        )
        return try makeFrame(
            prepared: prepared,
            outputColorSpace: outputColorSpace,
            metadata: metadata,
            frameIdentifier: monitoringIdentifier,
            metricsIdentifier: monitoringIdentifier
        )
    }

    private func makeFrame(
        prepared: PreparedImageNodeExecution,
        outputColorSpace: ImageColorSpaceContract?,
        metadata: [String: String],
        frameIdentifier: String,
        metricsIdentifier: String
    ) throws -> RenderedFrame {
        let output = try prepared.renderManagedTexture()
        do {
            return try makeFrame(
                prepared: prepared,
                texture: output.texture,
                lease: output.lease,
                outputColorSpace: outputColorSpace,
                metadata: metadata,
                frameIdentifier: frameIdentifier,
                metricsIdentifier: metricsIdentifier
            )
        } catch {
            output.lease?.release()
            throw error
        }
    }

    private func makeFrame(
        prepared: PreparedImageNodeExecution,
        texture: MTLTexture,
        lease: TextureLease?,
        outputColorSpace: ImageColorSpaceContract?,
        metadata: [String: String],
        frameIdentifier: String,
        metricsIdentifier: String
    ) throws -> RenderedFrame {
        let effectiveDerivative = prepared.derivative
        let renderRecipe = prepared.renderRecipe
        let diagnostics = prepared.diagnostics
        let primarySource = prepared.primarySource
        let resolvedOutputColorSpace = outputColorSpace ?? diagnostics.outputColorSpace
        let colorSpace = resolvedFrameColorSpace(for: primarySource, outputColorSpace: resolvedOutputColorSpace)
        let frameOutputColorSpace: ImageColorSpaceContract
        if resolvedOutputColorSpace.preservesInput == false {
            frameOutputColorSpace = resolvedOutputColorSpace
        } else if let colorSpace {
            frameOutputColorSpace = ImageColorSpaceContract(colorSpace: colorSpace)
        } else {
            frameOutputColorSpace = .preserveInput
        }
        let previewHostStrategy = resolvedPreviewHostStrategy(
            source: primarySource,
            renderedTexture: texture,
            renderRecipe: renderRecipe
        )
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.recordPreviewHostStrategy(
                metricsIdentifier,
                strategy: previewHostStrategy
            )
        }
        let previewHostPayload = makePreviewHostPayload(
            source: primarySource,
            renderedTexture: texture,
            renderRecipe: renderRecipe
        )
        var renderedMetadata = metadata
        renderedMetadata["filterChainFingerprint"] = FilterChainRecipe(filters: renderRecipe.filters).fingerprint
        renderedMetadata["renderExecutionFingerprint"] = prepared.executionFingerprint
        renderedMetadata["renderGraphFingerprint"] = diagnostics.graphFingerprint
        renderedMetadata["outputDynamicRange"] = frameOutputColorSpace.dynamicRange.rawValue
        renderedMetadata["outputColorSpace"] = frameOutputColorSpace.name
        renderedMetadata["outputToneMappingPolicy"] = diagnostics.outputContract.toneMappingPolicy.rawValue
        renderedMetadata["performanceMonitoringIdentifier"] = metricsIdentifier
        let token = FrameRenderToken(identifier: frameIdentifier, generation: FrameGeneration.next())
        let logicalOutputSize = C7Size(texture: texture)
        return RenderedFrame(
            texture: texture,
            colorSpace: colorSpace,
            outputColorSpaceContract: frameOutputColorSpace,
            outputToneMappingPolicy: diagnostics.outputContract.toneMappingPolicy,
            sourceDescriptor: primarySource.descriptor,
            derivative: effectiveDerivative,
            resolvedOutputSize: logicalOutputSize,
            renderIntent: effectiveDerivative.renderIntent,
            sourceTier: primarySource.sourceTier,
            alphaType: diagnostics.outputAlphaType ?? primarySource.alphaType,
            cachePolicy: resolvedCachePolicy,
            semantic: effectiveDerivative.semantic,
            orientation: primarySource.orientation,
            profile: prepared.profile,
            token: token,
            metadata: renderedMetadata,
            lease: lease,
            previewHostPayload: previewHostPayload
        )
    }

    /// 执行队列开始处理时解析渲染计划；提交不会深拷贝 source 或自定义引用类型滤镜。
    /// 调用方应保持共享参数不变，并独立保证输入资源的 GPU 生命周期与读写依赖。
    @discardableResult
    public func transmitFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:],
        submissionPolicy: RenderSubmissionPolicy = .independent,
        complete: @escaping @Sendable (Result<RenderedFrame, HarbethError>) -> Void
    ) -> RenderSubmissionHandle {
        let monitoringIdentifier = self.monitoringIdentifier
        let monitoringToken = "\(monitoringIdentifier).submission.\(UUID().uuidString)"
        let monitorEnabled = HarbethContext.shared.enablePerformanceMonitor
        if monitorEnabled {
            HarbethContext.shared.performanceMonitor.beginMonitoring(monitoringToken)
        }
        let finish: @Sendable (Result<RenderedFrame, HarbethError>) -> Void = { result in
            if monitorEnabled {
                HarbethContext.shared.performanceMonitor.endMonitoring(monitoringToken)
            }
            complete(result)
        }
        let state = HarbethUncheckedTransfer(value: (
            node: self, profile: profile, derivative: derivative, outputColorSpace: outputColorSpace, metadata: metadata
        ))
        return HarbethContext.shared.submitRenderOperation(
            sourceIdentifier: monitoringIdentifier,
            policy: submissionPolicy,
            execute: { submission in
                do {
                    let node = state.value.node
                    let prepared = try node.prepareExecution(profile: state.value.profile, derivative: state.value.derivative, executionIdentifier: monitoringToken)
                    if let transmitManagedTexture = prepared.transmitManagedTextureClosure {
                        transmitManagedTexture(submission) { result in
                            switch result {
                            case .success(let output):
                                do {
                                    let frame = try state.value.node.makeFrame(
                                        prepared: prepared,
                                        texture: output.texture,
                                        lease: output.lease,
                                        outputColorSpace: state.value.outputColorSpace,
                                        metadata: state.value.metadata,
                                        frameIdentifier: state.value.node.monitoringIdentifier,
                                        metricsIdentifier: monitoringToken
                                    )
                                    if submission.deliver({ finish(.success(frame)) }) == false {
                                        output.lease?.release()
                                    }
                                } catch {
                                    output.lease?.release()
                                    submission.deliver { finish(.failure(HarbethError.toHarbethError(error))) }
                                }
                            case .failure(let error):
                                submission.deliver { finish(.failure(error)) }
                            }
                        }
                        return
                    }
                    let frame = try node.makeFrame(
                        prepared: prepared,
                        outputColorSpace: state.value.outputColorSpace,
                        metadata: state.value.metadata,
                        frameIdentifier: node.monitoringIdentifier,
                        metricsIdentifier: monitoringToken
                    )
                    submission.deliver { finish(.success(frame)) }
                } catch {
                    submission.deliver { finish(.failure(HarbethError.toHarbethError(error))) }
                }
            },
            onDiscard: { _ in finish(.failure(.renderableTaskCancelled)) }
        )
    }

    public func startRenderFrameTask(profile: RenderProfile = .stablePreview,
                                     derivative: ImageDerivativeSpec? = nil,
                                     metadata: [String: String] = [:]) throws -> RenderTask<RenderedFrame> {
        let monitoringIdentifier = self.monitoringIdentifier
        let monitorEnabled = HarbethContext.shared.enablePerformanceMonitor
        if monitorEnabled { HarbethContext.shared.performanceMonitor.beginMonitoring(monitoringIdentifier) }
        defer { if monitorEnabled { HarbethContext.shared.performanceMonitor.endMonitoring(monitoringIdentifier) } }
        let prepared = try prepareExecution(profile: profile, derivative: derivative, executionIdentifier: monitoringIdentifier)
        let frame = try makeFrame(prepared: prepared, outputColorSpace: nil, metadata: metadata,
                                  frameIdentifier: monitoringIdentifier, metricsIdentifier: monitoringIdentifier)
        return .completed(identifier: frame.identifier, output: frame, diagnostics: prepared.diagnostics)
    }

    public func makeTexture(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        try makeTexture(profile: profile, derivative: derivative, executionIdentifier: nil)
    }

    private func makeTexture(profile: RenderProfile, derivative: ImageDerivativeSpec?, executionIdentifier: String?) throws -> MTLTexture {
        let effectiveCachePolicy = resolvedCachePolicy
        let fingerprint = resolutionFingerprint(profile: profile, derivative: derivative)
        if effectiveCachePolicy == .persistent,
           let cached = HarbethContext.shared.cachedResolvedTexture(for: fingerprint) {
            HarbethContext.shared.performanceMonitor.recordImageResolutionCacheLookup("imageResolution", hit: true)
            return cached
        }
        if effectiveCachePolicy == .persistent {
            HarbethContext.shared.performanceMonitor.recordImageResolutionCacheLookup("imageResolution", hit: false)
        }
        let texture = try makeTextureUncached(
            profile: profile,
            derivative: derivative,
            samplerDescriptor: .default,
            executionIdentifier: executionIdentifier
        )
        if effectiveCachePolicy == .persistent {
            HarbethContext.shared.storeResolvedTexture(texture, for: fingerprint)
        }
        return texture
    }

    public func makeDebugSnapshot(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderGraphDebugSnapshot {
        let sources = ImageNodeSourcePreparation()
        let plan = try makeRenderPlan(profile: profile, derivative: derivative, sources: sources)
        let graph = try plan.imageGraph ?? makeImageGraph(profile: profile, derivative: derivative)
        let renderRecipe = try makeRenderRecipe(
            profile: profile,
            derivative: derivative,
            preparedPlan: plan,
            sources: sources
        )
        return RenderGraphDebugSnapshot(
            graph: graph,
            diagnostics: plan.diagnostics,
            optimizationDecisions: plan.diagnostics.graphOptimizationDecisions,
            renderRecipe: renderRecipe
        )
    }

    public func makeImageGraph(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> ImageGraph {
        let builder = ImageGraphBuilder(profile: profile, derivative: derivative ?? profile.defaultDerivativeSpec)
        return try builder.build(from: self)
    }

    public func makeDiagnostics(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        try makeRenderPlan(profile: profile, derivative: derivative).diagnostics
    }

    public func makeAttachmentDebugPolicies(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> [RenderOutputAttachmentDebugPolicy] {
        try makeDiagnostics(profile: profile, derivative: derivative).outputAttachmentDebugPolicies
    }

    public func makeHistogram(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .cpuReadback
    ) throws -> TextureHistogram? {
        try makeFrame(profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    public func makeHistogram(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .cpuReadback
    ) throws -> TextureHistogram? {
        try makeFrame(profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeHistogramAttachment(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        height: Int = 64,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedHistogramAttachment? {
        try makeFrame(profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    public func makeHistogramAttachment(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        height: Int = 64,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedHistogramAttachment? {
        try makeFrame(profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        histogramHeight: Int = 64,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAnalysisBundle {
        let frame = try makeFrame(profile: profile, derivative: derivative)
        return RenderedAnalysisBundle.makeScopeBundle(
            frame: frame,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: TextureAnalysisScope(
                region: region,
                mask: mask,
                luminanceRange: luminanceRange,
                colorRange: colorRange,
                coverageThreshold: coverageThreshold
            ),
            preferredMethod: preferredMethod,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    public func makeAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        histogramHeight: Int = 64,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAnalysisBundle {
        let frame = try makeFrame(profile: profile, derivative: derivative)
        return RenderedAnalysisBundle.makeScopeBundle(
            frame: frame,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    public func makeStatistics(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5
    ) throws -> TextureStatistics? {
        try makeFrame(profile: profile, derivative: derivative).makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeStatistics(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        scope: TextureAnalysisScope
    ) throws -> TextureStatistics? {
        try makeFrame(profile: profile, derivative: derivative).makeStatistics(scope: scope)
    }

    public func makeColorProbe(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        x: Int,
        y: Int,
        radius: Int = 0,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5
    ) throws -> TextureColorProbe? {
        try makeFrame(profile: profile, derivative: derivative).makeColorProbe(
            x: x,
            y: y,
            radius: radius,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeColorProbe(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5
    ) throws -> TextureColorProbe? {
        try makeFrame(profile: profile, derivative: derivative).makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeColorProbe(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        scope: TextureAnalysisScope
    ) throws -> TextureColorProbe? {
        try makeFrame(profile: profile, derivative: derivative).makeColorProbe(scope: scope)
    }

    public func makeMaskTexture(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        scope: TextureAnalysisScope,
        pixelFormat: MTLPixelFormat = .rgba8Unorm
    ) throws -> MTLTexture? {
        try makeFrame(profile: profile, derivative: derivative).makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    public func makeMaskDescriptor(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        scope: TextureAnalysisScope,
        component: MaskComponent = .red,
        blendMode: MaskBlendMode = .mix,
        invert: Bool = false,
        featherPolicy: MaskFeatherPolicy = .none,
        opacity: Float = 1.0,
        pixelFormat: MTLPixelFormat = .rgba8Unorm
    ) throws -> MaskDescriptor? {
        try makeFrame(profile: profile, derivative: derivative).makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }

    public func makeAttachmentSet(profile: RenderProfile = .readbackQuality) throws -> RenderedAttachmentSet? {
        guard let route = try prepareAttachmentRoute(profile: profile) else { return nil }
        return try route.renderAttachmentSet(
            identifier: "ImageNode.AttachmentSet.\(UUID().uuidString)"
        )
    }

    public func makeAttachment(profile: RenderProfile = .readbackQuality, semantic: RenderOutputAttachmentSemantic) throws -> RenderedAttachment? {
        try makeAttachmentSet(profile: profile)?.attachment(for: semantic)
    }

    public func makeAttachmentAnalysis(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        channel: TextureHistogramChannel? = nil,
        bins: Int = 256,
        histogramHeight: Int = 64,
        region: MTLRegion? = nil,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAttachmentAnalysis? {
        try makeAttachmentSet(profile: profile)?.makeAnalysis(
            for: semantic,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentAnalysis(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        channel: TextureHistogramChannel? = nil,
        bins: Int = 256,
        histogramHeight: Int = 64,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAttachmentAnalysis? {
        try makeAttachmentSet(profile: profile)?.makeAnalysis(
            for: semantic,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentHistogram(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        channel: TextureHistogramChannel? = nil,
        bins: Int = 256,
        region: MTLRegion? = nil,
        preferredMethod: TextureHistogramComputationMethod = .cpuReadback
    ) throws -> TextureHistogram? {
        try makeAttachmentSet(profile: profile)?.makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentHistogram(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        channel: TextureHistogramChannel? = nil,
        bins: Int = 256,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .cpuReadback
    ) throws -> TextureHistogram? {
        try makeAttachmentSet(profile: profile)?.makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentStatistics(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5
    ) throws -> TextureStatistics? {
        try makeAttachmentSet(profile: profile)?.makeStatistics(
            for: semantic,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeAttachmentStatistics(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        scope: TextureAnalysisScope
    ) throws -> TextureStatistics? {
        try makeAttachmentSet(profile: profile)?.makeStatistics(for: semantic, scope: scope)
    }

    public func makeAttachmentColorProbe(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        colorRange: TextureColorRange? = nil,
        coverageThreshold: Float = 0.5
    ) throws -> TextureColorProbe? {
        try makeAttachmentSet(profile: profile)?.makeColorProbe(
            for: semantic,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeAttachmentColorProbe(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        scope: TextureAnalysisScope
    ) throws -> TextureColorProbe? {
        try makeAttachmentSet(profile: profile)?.makeColorProbe(for: semantic, scope: scope)
    }

    public func makeAttachmentMaskTexture(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        scope: TextureAnalysisScope,
        pixelFormat: MTLPixelFormat = .rgba8Unorm
    ) throws -> MTLTexture? {
        try makeAttachmentSet(profile: profile)?.makeMaskTexture(for: semantic, scope: scope, pixelFormat: pixelFormat)
    }

    public func makeAttachmentMaskDescriptor(
        profile: RenderProfile = .readbackQuality,
        semantic: RenderOutputAttachmentSemantic,
        scope: TextureAnalysisScope,
        component: MaskComponent = .red,
        blendMode: MaskBlendMode = .mix,
        invert: Bool = false,
        featherPolicy: MaskFeatherPolicy = .none,
        opacity: Float = 1.0,
        pixelFormat: MTLPixelFormat = .rgba8Unorm
    ) throws -> MaskDescriptor? {
        try makeAttachmentSet(profile: profile)?.makeMaskDescriptor(
            for: semantic,
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }

    public func makeAttachmentAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        bins: Int = 256,
        histogramHeight: Int = 64,
        region: MTLRegion? = nil,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAttachmentAnalysisBundle? {
        guard let route = try prepareAttachmentRoute(profile: profile) else { return nil }
        return try route.renderAnalysisBundle(
            identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        bins: Int = 256,
        histogramHeight: Int = 64,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAttachmentAnalysisBundle? {
        guard let route = try prepareAttachmentRoute(profile: profile) else { return nil }
        return try route.renderAnalysisBundle(
            identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeRenderRequest(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let prepared = try prepareExecution(
            profile: profile,
            derivative: effectiveDerivative,
            executionIdentifier: monitoringIdentifier
        )
        let attachmentPolicies = prepared.diagnostics.outputAttachmentDebugPolicies
        let preparedAttachmentRoute = try prepareAttachmentRoute(profile: profile)
        return RenderRequest.makeFrameBackedRequest(
            compilationSource: prepared.diagnostics.compilationSource,
            profile: profile,
            derivative: effectiveDerivative,
            source: prepared.primarySource.descriptor,
            outputCachePolicy: resolvedCachePolicy,
            diagnostics: prepared.diagnostics,
            renderRecipe: prepared.renderRecipe,
            renderTexture: { try prepared.renderTexture() },
            renderFrame: { metadata in
                let identifier = monitoringIdentifier
                let monitorEnabled = HarbethContext.shared.enablePerformanceMonitor
                if monitorEnabled { HarbethContext.shared.performanceMonitor.beginMonitoring(identifier) }
                defer {
                    if monitorEnabled {
                        HarbethContext.shared.performanceMonitor.endMonitoring(identifier)
                    }
                }
                return try makeFrame(
                    prepared: prepared,
                    outputColorSpace: nil,
                    metadata: metadata,
                    frameIdentifier: identifier,
                    metricsIdentifier: identifier
                )
            },
            attachmentDebugPolicies: attachmentPolicies,
            renderAttachmentSet: {
                try preparedAttachmentRoute?.renderAttachmentSet(
                    identifier: "ImageNode.AttachmentSet.\(UUID().uuidString)"
                )
            },
            renderAttachmentAnalysisBundle: { bins, histogramHeight, region, preferredMethod in
                try preparedAttachmentRoute?.renderAnalysisBundle(
                    identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
                    bins: bins,
                    histogramHeight: histogramHeight,
                    region: region,
                    preferredMethod: preferredMethod
                )
            },
            renderAttachmentAnalysisScopeBundle: { bins, histogramHeight, scope, preferredMethod in
                try preparedAttachmentRoute?.renderAnalysisBundle(
                    identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
                    bins: bins,
                    histogramHeight: histogramHeight,
                    scope: scope,
                    preferredMethod: preferredMethod
                )
            }
        )
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
extension ImageNode {
    public func makeFrameAsync(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:],
        submissionPolicy: RenderSubmissionPolicy = .independent
    ) async throws -> RenderedFrame {
        let relay = RenderSubmissionCancellationRelay()
        let transfer: HarbethUncheckedTransfer<RenderedFrame> = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let handle = transmitFrame(
                    profile: profile,
                    derivative: derivative,
                    outputColorSpace: outputColorSpace,
                    metadata: metadata,
                    submissionPolicy: submissionPolicy
                ) { result in
                    switch result {
                    case .success(let frame):
                        continuation.resume(returning: HarbethUncheckedTransfer(value: frame))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                relay.store(handle)
            }
        }, onCancel: {
            relay.cancel()
        })
        return transfer.value
    }
}

extension ImageNode: ImagePromise {
    var compilationSource: RenderCompilationSource {
        switch storage {
        case .source:
            return .nodeGraph
        case .filters(let input, _):
            return input.compilationSource
        case .kernel(let input, _, _):
            return input.compilationSource
        case .edit:
            return .editRecipe
        case .transition:
            return .transition
        case .layerComposite:
            return .layerComposite
        case .cachePolicy(let input, _):
            return input.compilationSource
        case .samplerDescriptor(let input, _):
            return input.compilationSource
        }
    }

    private func makeTextureUncached(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        samplerDescriptor: ImageSamplerDescriptor,
        executionIdentifier: String?
    ) throws -> MTLTexture {
        switch storage {
        case .source(let source):
            if let io = try source.planeAwareIO(filters: [], profile: profile, identifier: executionIdentifier ?? monitoringIdentifier,
                                               derivative: derivative ?? profile.defaultDerivativeSpec) {
                return try io.output()
            }
            let texture = try source.makeTexture()
            return try resizeTextureIfNeeded(
                texture,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                profile: profile,
                executionIdentifier: executionIdentifier
            )
        case .filters:
            let route = flattenedFilterRoute()
            let input = route.input
            let filters = route.filters
            if case .source(let source) = input.storage,
               let io = try source.planeAwareIO(filters: SamplerExecutionAdapter.makePlan(filters: filters, samplerDescriptor: samplerDescriptor).filters,
                    profile: profile, identifier: executionIdentifier ?? monitoringIdentifier,
                    derivative: derivative ?? profile.defaultDerivativeSpec) {
                return try io.output()
            }
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
            let program = RenderExecutionCompiler.compile(
                filters: filters,
                inputSize: C7Size(texture: inputTexture),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: input.compilationSource,
                samplerDescriptor: samplerDescriptor,
                sourceDescriptor: try input.resolvedPrimarySource().descriptor
            )
            let io = HarbethIO<MTLTexture>(
                element: inputTexture,
                filters: filters,
                identifier: executionIdentifier ?? monitoringIdentifier
            ).configured(for: profile)
            return try io.executeRenderProgram(input: inputTexture, program: program)
        case .kernel(let input, let descriptor, let filter):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
            try descriptor.validateCompatibility(with: filter, inputSize: C7Size(texture: inputTexture))
            let rendered = try HarbethIO(
                element: inputTexture,
                filter: SamplerExecutionAdapter.adapt(filter: filter, samplerDescriptor: samplerDescriptor),
                identifier: executionIdentifier ?? monitoringIdentifier
            ).configured(for: profile).output()
            let contracted = try ImageNode.applyOutputContractIfNeeded(
                descriptor.outputContract,
                to: rendered,
                sourceColorSpace: descriptor.inputColorSpace,
                sourceAlphaType: descriptor.outputContract.inputAlphaExpectation.expectedAlphaType,
                profile: profile,
                identifier: executionIdentifier ?? monitoringIdentifier
            )
            return try resizeTextureIfNeeded(
                contracted,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                profile: profile,
                executionIdentifier: executionIdentifier
            )
        case .edit(let input, let recipe, let mode):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
            return try FrameRenderer(
                source: .texture(inputTexture),
                recipe: recipe,
                mode: mode,
                identifier: executionIdentifier ?? monitoringIdentifier,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor
            ).renderTexture()
        case .transition(let recipe):
            return try FrameRenderer(
                transitionRecipe: recipe,
                profile: profile,
                derivative: derivative,
                identifier: executionIdentifier ?? monitoringIdentifier,
                samplerDescriptor: samplerDescriptor
            ).renderTexture()
        case .layerComposite(let recipe):
            return try recipe.makeTexture(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier ?? monitoringIdentifier
            )
        case .cachePolicy(let input, _):
            return try input.makeTextureUncached(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
        case .samplerDescriptor(let input, let descriptor):
            return try input.makeTextureUncached(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: descriptor,
                executionIdentifier: executionIdentifier
            )
        }
    }

    func resolutionFingerprint(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) -> String {
        Self.resolutionFingerprint(
            nodeFingerprint: nodeFingerprint,
            profile: profile,
            derivative: derivative ?? profile.defaultDerivativeSpec,
            cachePolicy: resolvedCachePolicy,
            samplerDescriptor: resolvedSamplerDescriptor
        )
    }

    static func resolutionFingerprint(
        nodeFingerprint: String,
        profile: RenderProfile,
        derivative: ImageDerivativeSpec,
        cachePolicy: ImageCachePolicy,
        samplerDescriptor: ImageSamplerDescriptor
    ) -> String {
        return [
            nodeFingerprint, "profile=\(profile)", derivative.fingerprint,
            "cache=\(cachePolicy.rawValue)", "sampler=\(samplerDescriptor.fingerprint)",
        ].joined(separator: " || ")
    }

    func makeOptimizedImageGraph(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> ImageGraphOptimizationResult {
        ImageGraphOptimizer.optimize(try makeImageGraph(profile: profile, derivative: derivative))
    }

    func makeRenderPlan(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        samplerDescriptorOverride: ImageSamplerDescriptor? = nil,
        sources: ImageNodeSourcePreparation? = nil
    ) throws -> RenderPlan {
        let sources = sources ?? ImageNodeSourcePreparation()
        var preparations: [ImageNodeRenderPlanPreparation] = []
        var node = self
        var nextDerivative = derivative
        var samplerOverride = samplerDescriptorOverride
        var inputPlan: RenderPlan?

        // 规划也按输入依赖迭代展开；父节点的编译栈帧只在其输入就绪后出现。
        while true {
            let sampler = samplerOverride ?? node.resolvedSamplerDescriptor
            let cacheKey = ImageNode.makeRenderPlanCacheKey(
                nodeFingerprint: node.nodeFingerprint,
                profile: profile,
                derivative: nextDerivative ?? profile.defaultDerivativeSpec,
                samplerDescriptor: sampler
            )
            if let cached = HarbethContext.shared.cachedRenderPlan(for: cacheKey) {
                HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("renderPlan", hit: true)
                inputPlan = cached
                break
            }
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("renderPlan", hit: false)
            let optimization = try node.makeOptimizedImageGraph(profile: profile, derivative: nextDerivative)
            preparations.append(ImageNodeRenderPlanPreparation(
                node: node,
                derivative: nextDerivative,
                samplerDescriptor: sampler,
                cacheKey: cacheKey,
                optimization: optimization
            ))
            guard let input = node.renderPlanInput(
                profile: profile,
                derivative: nextDerivative,
                samplerDescriptor: sampler
            ) else { break }
            node = input.node
            nextDerivative = input.derivative
            samplerOverride = input.samplerDescriptor
        }

        for preparation in preparations.reversed() {
            let plan = try preparation.node.compileRenderPlan(
                from: preparation,
                inputPlan: inputPlan,
                profile: profile,
                sources: sources
            )
            HarbethContext.shared.storeRenderPlan(plan, for: preparation.cacheKey)
            inputPlan = plan
        }
        guard let inputPlan else { preconditionFailure("规划至少包含一个来源节点。") }
        return inputPlan
    }

    private func renderPlanInput(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        samplerDescriptor: ImageSamplerDescriptor
    ) -> (node: ImageNode, derivative: ImageDerivativeSpec?, samplerDescriptor: ImageSamplerDescriptor)? {
        let input: ImageNode
        switch storage {
        case .filters:
            input = flattenedFilterRoute().input
            if case .transition = input.storage { return nil }
        case .kernel(let upstream, _, _):
            input = upstream
        case .edit(let input, _, _):
            return (input, nil, samplerDescriptor)
        case .cachePolicy(let input, _):
            return (input, derivative, samplerDescriptor)
        case .samplerDescriptor(let input, let descriptor):
            _ = HarbethContext.shared.makeSamplerState(descriptor)
            return (input, derivative, descriptor)
        case .source, .transition, .layerComposite:
            return nil
        }
        if case .edit(let upstream, _, _) = input.storage {
            return (upstream, nil, samplerDescriptor)
        }
        guard input.resolvedPlanningOutputSizeHint(profile: profile) == nil else { return nil }
        return (input, nil, samplerDescriptor)
    }

    private func compileRenderPlan(
        from preparation: ImageNodeRenderPlanPreparation,
        inputPlan: RenderPlan?,
        profile: RenderProfile,
        sources: ImageNodeSourcePreparation
    ) throws -> RenderPlan {
        let derivative = preparation.derivative
        let activeSamplerDescriptor = preparation.samplerDescriptor
        let optimization = preparation.optimization
        let plan: RenderPlan
        switch storage {
        case .cachePolicy(let input, let policy):
            guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
            plan = try makeCachePolicyRenderPlan(
                input: input,
                innerPlan: inputPlan,
                policy: policy,
                optimization: optimization
            )
        case .samplerDescriptor(let input, let descriptor):
            guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
            plan = try makeSamplerDescriptorRenderPlan(
                input: input,
                innerPlan: inputPlan,
                descriptor: descriptor,
                optimization: optimization
            )
        case .edit(let input, let recipe, let mode):
            guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
            plan = try makeEditRenderPlan(
                input: input,
                inputPlan: inputPlan,
                recipe: recipe,
                mode: mode,
                profile: profile,
                derivative: derivative,
                samplerDescriptor: activeSamplerDescriptor,
                optimization: optimization
            )
        default:
            plan = try makeUnwrappedRenderPlan(
                profile: profile,
                inputPlan: inputPlan,
                derivative: derivative,
                samplerDescriptor: activeSamplerDescriptor,
                optimization: optimization,
                sources: sources
            )
        }
        return plan
    }

    private func makeUnwrappedRenderPlan(
        profile: RenderProfile,
        inputPlan: RenderPlan?,
        derivative: ImageDerivativeSpec?,
        samplerDescriptor activeSamplerDescriptor: ImageSamplerDescriptor,
        optimization: ImageGraphOptimizationResult,
        sources: ImageNodeSourcePreparation
    ) throws -> RenderPlan {
        var plan: RenderPlan
        switch storage {
        case .source(let source):
            let inputSize: C7Size
            if let size = source.resolvedSizeHint {
                inputSize = size
            } else {
                let texture = try sources.texture(for: source)
                inputSize = C7Size(texture: texture)
            }
            plan = GraphCompiler.compile(
                filters: [],
                inputSize: inputSize,
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                imageCachePolicy: source.cachePolicy,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: source.descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        case .filters:
            let route = flattenedFilterRoute()
            let input = route.input
            let filters = route.filters
            switch input.storage {
            case .edit(let upstream, let recipe, let mode):
                guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
                let inputSize = inputPlan.diagnostics.outputSize
                plan = try makeWrappedEditRenderPlan(
                    source: try upstream.resolvedPrimarySource(),
                    inputSize: inputSize,
                    recipe: recipe,
                    mode: mode,
                    extraFilters: filters,
                    profile: profile,
                    derivative: derivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: try upstream.resolvedPrimarySource().descriptor,
                    optimization: optimization,
                    upstreamContract: inputPlan.diagnostics.outputContract
                )
            case .transition(let recipe):
                let inputSize: C7Size
                if let size = recipe.from.resolvedSizeHint {
                    inputSize = size
                } else {
                    let texture = try sources.texture(for: recipe.from)
                    inputSize = C7Size(texture: texture)
                }
                plan = RenderExecutionCompiler.compile(
                    filters: [try recipe.makeFilter()] + filters,
                    inputSize: inputSize,
                    profile: profile,
                    derivative: derivative ?? recipe.derivative,
                    compilationSource: .transition,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: recipe.from.descriptor,
                    auxiliaryInputDescriptor: recipe.to.descriptor,
                    imageGraph: optimization.graph,
                    graphOptimizationDecisions: optimization.decisions
                ).plan
            default:
                let inputSize: C7Size
                if let size = input.resolvedPlanningOutputSizeHint(profile: profile) {
                    inputSize = size
                } else {
                    guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
                    inputSize = inputPlan.diagnostics.outputSize
                }
                let localPlan = RenderExecutionCompiler.compile(
                    filters: filters,
                    inputSize: inputSize,
                    profile: profile,
                    derivative: derivative ?? profile.defaultDerivativeSpec,
                    compilationSource: input.compilationSource,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: (try input.resolvedPrimarySource()).descriptor,
                    imageGraph: optimization.graph,
                    graphOptimizationDecisions: optimization.decisions
                ).plan
                let inputCoverage: SamplerExecutionCoverage
                if let inputPlan {
                    inputCoverage = inputPlan.diagnostics.samplerExecutionCoverage
                } else {
                    inputCoverage = try input.resolvedSamplerExecutionCoverage(
                        profile: profile,
                        samplerDescriptor: activeSamplerDescriptor
                    )
                }
                plan = localPlan.withSamplerExecutionCoverage(
                    SamplerExecutionAdapter.merge(inputCoverage, localPlan.diagnostics.samplerExecutionCoverage)
                )
            }
        case .kernel(let input, let descriptor, let filter):
            switch input.storage {
            case .edit(let upstream, let recipe, let mode):
                guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
                let inputSize = inputPlan.diagnostics.outputSize
                try descriptor.validateCompatibility(with: filter, inputSize: inputSize)
                plan = try makeWrappedEditRenderPlan(
                    source: try upstream.resolvedPrimarySource(),
                    inputSize: inputSize,
                    recipe: recipe,
                    mode: mode,
                    extraFilters: [filter],
                    profile: profile,
                    derivative: derivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: try upstream.resolvedPrimarySource().descriptor,
                    optimization: optimization
                )
            default:
                let inputSize: C7Size
                if let size = input.resolvedPlanningOutputSizeHint(profile: profile) {
                    inputSize = size
                } else {
                    guard let inputPlan else { preconditionFailure("上游规划必须先于当前节点完成。") }
                    inputSize = inputPlan.diagnostics.outputSize
                }
                try descriptor.validateCompatibility(with: filter, inputSize: inputSize)
                let localPlan = RenderExecutionCompiler.compile(
                    filters: [filter],
                    inputSize: inputSize,
                    profile: profile,
                    derivative: derivative ?? profile.defaultDerivativeSpec,
                    compilationSource: input.compilationSource,
                    outputContract: descriptor.outputContract,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: (try input.resolvedPrimarySource()).descriptor,
                    imageGraph: optimization.graph,
                    graphOptimizationDecisions: optimization.decisions
                ).plan
                let inputCoverage: SamplerExecutionCoverage
                if let inputPlan {
                    inputCoverage = inputPlan.diagnostics.samplerExecutionCoverage
                } else {
                    inputCoverage = try input.resolvedSamplerExecutionCoverage(
                        profile: profile,
                        samplerDescriptor: activeSamplerDescriptor
                    )
                }
                plan = localPlan.withSamplerExecutionCoverage(
                    SamplerExecutionAdapter.merge(inputCoverage, localPlan.diagnostics.samplerExecutionCoverage)
                )
            }
        case .transition(let recipe):
            let inputSize: C7Size
            if let size = recipe.from.resolvedSizeHint {
                inputSize = size
            } else {
                let texture = try sources.texture(for: recipe.from)
                inputSize = C7Size(texture: texture)
            }
            plan = RenderExecutionCompiler.compile(
                filters: [try recipe.makeFilter()],
                inputSize: inputSize,
                profile: profile,
                derivative: derivative ?? recipe.derivative,
                compilationSource: .transition,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: recipe.from.descriptor,
                auxiliaryInputDescriptor: recipe.to.descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            ).plan
        case .layerComposite(let recipe):
            plan = try recipe.makeRenderPlan(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: activeSamplerDescriptor
            )
        case .edit, .cachePolicy, .samplerDescriptor:
            preconditionFailure("递归编辑节点与包装节点必须先经过轻量规划分派。")
        }
        return plan
    }

    private func makeEditRenderPlan(
        input: ImageNode,
        inputPlan: RenderPlan,
        recipe: EditRecipe,
        mode: EditRecipeMode,
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        samplerDescriptor: ImageSamplerDescriptor,
        optimization: ImageGraphOptimizationResult
    ) throws -> RenderPlan {
        let inputSize = inputPlan.diagnostics.outputSize
        return try makeWrappedEditRenderPlan(
            source: try input.resolvedPrimarySource(),
            inputSize: inputSize,
            recipe: recipe,
            mode: mode,
            extraFilters: [],
            profile: profile,
            derivative: derivative,
            samplerDescriptor: samplerDescriptor,
            sourceDescriptor: try input.resolvedPrimarySource().descriptor,
            optimization: optimization,
            upstreamContract: inputPlan.diagnostics.outputContract
        )
    }

    private func makeCachePolicyRenderPlan(
        input: ImageNode,
        innerPlan: RenderPlan,
        policy: ImageCachePolicy,
        optimization: ImageGraphOptimizationResult
    ) throws -> RenderPlan {
        return RenderPlan(
            graph: innerPlan.graph,
            profile: innerPlan.profile,
            derivative: innerPlan.diagnostics.derivative,
            inputSize: innerPlan.diagnostics.inputSize,
            outputSize: innerPlan.diagnostics.outputSize,
            nodeDiagnostics: innerPlan.diagnostics.nodes,
            compilationSource: innerPlan.diagnostics.compilationSource,
            outputContract: innerPlan.diagnostics.outputContract,
            imageCachePolicy: policy,
            samplerDescriptor: innerPlan.diagnostics.samplerDescriptor,
            samplerExecutionCoverage: innerPlan.diagnostics.samplerExecutionCoverage,
            sourceDescriptor: try input.resolvedPrimarySource().descriptor,
            inputColorConversionCount: innerPlan.diagnostics.inputColorConversionCount,
            inputPixelFormatConversionCount: innerPlan.diagnostics.inputPixelFormatConversionCount,
            inputAlphaConversionCount: innerPlan.diagnostics.inputAlphaConversionCount,
            imageGraph: optimization.graph,
            graphOptimizationDecisions: optimization.decisions
        )
    }

    private func makeSamplerDescriptorRenderPlan(
        input: ImageNode,
        innerPlan: RenderPlan,
        descriptor: ImageSamplerDescriptor,
        optimization: ImageGraphOptimizationResult
    ) throws -> RenderPlan {
        return RenderPlan(
            graph: innerPlan.graph,
            profile: innerPlan.profile,
            derivative: innerPlan.diagnostics.derivative,
            inputSize: innerPlan.diagnostics.inputSize,
            outputSize: innerPlan.diagnostics.outputSize,
            nodeDiagnostics: innerPlan.diagnostics.nodes,
            compilationSource: innerPlan.diagnostics.compilationSource,
            outputContract: innerPlan.diagnostics.outputContract,
            imageCachePolicy: innerPlan.diagnostics.imageCachePolicy,
            samplerDescriptor: descriptor,
            samplerExecutionCoverage: innerPlan.diagnostics.samplerExecutionCoverage,
            sourceDescriptor: try input.resolvedPrimarySource().descriptor,
            inputColorConversionCount: innerPlan.diagnostics.inputColorConversionCount,
            inputPixelFormatConversionCount: innerPlan.diagnostics.inputPixelFormatConversionCount,
            inputAlphaConversionCount: innerPlan.diagnostics.inputAlphaConversionCount,
            imageGraph: optimization.graph,
            graphOptimizationDecisions: optimization.decisions
        )
    }

    /// Builds the LRU cache key for a `makeRenderPlan` call.
    /// Same `(node, profile, derivative, samplerDescriptor)` → same key.
    static func makeRenderPlanCacheKey(
        nodeFingerprint: String,
        profile: RenderProfile,
        derivative: ImageDerivativeSpec,
        samplerDescriptor: ImageSamplerDescriptor
    ) -> String {
        "\(nodeFingerprint)|profile=\(profile.rawValue)|derivative=\(derivative.fingerprint)|sampler=\(samplerDescriptor.fingerprint)"
    }

    func makeRenderRecipe(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        preparedPlan: RenderPlan? = nil,
        sources: ImageNodeSourcePreparation? = nil,
        preparedInputRecipe: RenderRecipe? = nil,
        samplerDescriptorOverride: ImageSamplerDescriptor? = nil
    ) throws -> RenderRecipe {
        let sampler = samplerDescriptorOverride ?? preparedPlan?.diagnostics.samplerDescriptor ?? resolvedSamplerDescriptor
        switch storage {
        case .filters:
            let route = flattenedFilterRoute()
            let base = try route.input.makeRenderRecipe(
                profile: profile, derivative: derivative, sources: sources, samplerDescriptorOverride: sampler
            )
            return base.appending(filterDescriptors: route.filters.map { $0.recipeDescriptor.withSamplerContract(sampler) })
        case .kernel(let input, _, let filter):
            let base = try input.makeRenderRecipe(
                profile: profile, derivative: derivative, sources: sources, samplerDescriptorOverride: sampler
            )
            return base.appending(filterDescriptors: [filter.recipeDescriptor.withSamplerContract(sampler)])
        case .edit(let input, let recipe, let mode):
            let plan = try preparedPlan ?? makeRenderPlan(
                profile: profile, derivative: derivative, samplerDescriptorOverride: sampler, sources: sources
            )
            let originalSource = try input.resolvedPrimarySource()
            let upstream = try preparedInputRecipe ?? input.makeRenderRecipe(
                profile: profile, derivative: profile.defaultDerivativeSpec, sources: sources, samplerDescriptorOverride: sampler
            )
            return try recipe.makeRenderRecipe(
                source: originalSource,
                mode: mode,
                derivative: derivative,
                samplerDescriptor: plan.diagnostics.samplerDescriptor,
                sourceDescriptorOverride: originalSource.descriptor,
                alphaTypeOverride: originalSource.alphaType,
                orientationOverride: originalSource.orientation,
                preparedPlan: plan
            ).withUpstreamProcessing(from: upstream)
        case .layerComposite(let recipe):
            return try recipe.makeRenderRecipe(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: sampler
            )
        case .cachePolicy(let input, let policy):
            let base = try input.makeRenderRecipe(
                profile: profile, derivative: derivative, sources: sources, samplerDescriptorOverride: sampler
            )
            return base.with(outputCachePolicy: policy)
        case .samplerDescriptor(let input, let descriptor):
            return try input.makeRenderRecipe(
                profile: profile, derivative: derivative, sources: sources, samplerDescriptorOverride: descriptor
            )
        default:
            break
        }
        let plan = try preparedPlan ?? makeRenderPlan(
            profile: profile, derivative: derivative, samplerDescriptorOverride: sampler, sources: sources
        )
        let primarySource = try resolvedPrimarySource()
        let filters = plan.diagnostics.nodes.filter { $0.name != "DerivativeResize" }.map { diagnostic in
            FilterRecipeDescriptor(
                stableTypeID: diagnostic.name,
                modifier: diagnostic.kind.rawValue,
                parameterValues: diagnostic.parameterSummary.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" },
                resourceIdentity: nil,
                otherInputTextureCount: 0,
                pipelineFilterFingerprints: [],
                finalFilterFingerprint: nil
            ).withSamplerContract(plan.diagnostics.samplerDescriptor)
        }
        return RenderRecipe(
            renderProfile: String(describing: plan.profile),
            renderIntent: plan.diagnostics.derivative.renderIntent,
            source: primarySource.descriptor,
            outputDerivative: plan.diagnostics.derivative,
            outputCachePolicy: resolvedCachePolicy,
            outputSemantic: plan.diagnostics.derivative.semantic,
            alphaType: primarySource.alphaType,
            orientation: primarySource.orientation,
            filters: filters,
            localEffects: nil,
            layerMasks: nil
        )
    }

    private func resizeTextureIfNeeded(
        _ texture: MTLTexture,
        derivative: ImageDerivativeSpec,
        profile: RenderProfile,
        executionIdentifier: String? = nil
    ) throws -> MTLTexture {
        try ImageNode.applyDerivativeResize(
            texture,
            derivative: derivative,
            profile: profile,
            identifier: executionIdentifier ?? monitoringIdentifier
        )
    }

    /// Resize a texture to match the target size defined by `derivative`.
    /// Returns the input unchanged when sizes already match.
    ///
    /// Single source of truth for derivative-driven resizing, shared between
    /// `ImageNode.makeTextureUncached` and `LayerCompositeRecipe.makeTexture`.
    static func applyDerivativeResize(
        _ texture: MTLTexture,
        derivative: ImageDerivativeSpec,
        profile: RenderProfile,
        identifier: String? = nil
    ) throws -> MTLTexture {
        let targetSize = derivative.resolvedOutputSize(for: C7Size(texture: texture))
        guard targetSize.width != texture.width || targetSize.height != texture.height else { return texture }
        return try HarbethIO(
            element: texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height)),
            identifier: identifier ?? "ImageNode.DerivativeResize"
        ).configured(for: profile).output()
    }

    /// 仅收集连续 filters 节点，分组按外层到源端排列，保留空组和所有非 filters 边界。
    func groupedFilterRoute() -> (input: ImageNode, groups: [[C7FilterProtocol]]) {
        var input = self
        var groups: [[C7FilterProtocol]] = []
        while case .filters(let upstream, let filters) = input.storage {
            groups.append(filters)
            input = upstream
        }
        return (input, groups)
    }

    private func flattenedFilterRoute() -> (input: ImageNode, filters: [C7FilterProtocol]) {
        let route = groupedFilterRoute()
        return (route.input, route.groups.reversed().flatMap { $0 })
    }

    private var monitoringIdentifier: String { "ImageNode.\(nodeFingerprint)" }

    var resolvedCachePolicy: ImageCachePolicy {
        switch storage {
        case .source(let source):
            return source.cachePolicy
        case .filters(let input, _):
            return input.resolvedCachePolicy
        case .kernel(let input, _, _):
            return input.resolvedCachePolicy
        case .edit(let input, _, _):
            return input.resolvedCachePolicy
        case .transition(let recipe):
            return recipe.from.cachePolicy
        case .layerComposite(let recipe):
            return recipe.background.cachePolicy
        case .cachePolicy(_, let policy):
            return policy
        case .samplerDescriptor(let input, _):
            return input.resolvedCachePolicy
        }
    }

    var resolvedSamplerDescriptor: ImageSamplerDescriptor {
        switch storage {
        case .samplerDescriptor(_, let descriptor):
            return descriptor
        case .cachePolicy(let input, _):
            return input.resolvedSamplerDescriptor
        case .source, .filters, .kernel, .edit, .transition, .layerComposite:
            return .default
        }
    }

    private func resolvedSamplerExecutionCoverage(
        profile: RenderProfile,
        samplerDescriptor: ImageSamplerDescriptor
    ) throws -> SamplerExecutionCoverage {
        switch storage {
        case .source:
            return SamplerExecutionCoverage(mode: .notApplicable)
        case .filters(let input, let filters):
            return SamplerExecutionAdapter.merge(
                try input.resolvedSamplerExecutionCoverage(
                    profile: profile,
                    samplerDescriptor: samplerDescriptor
                ),
                SamplerExecutionAdapter.makePlan(
                    filters: filters,
                    samplerDescriptor: samplerDescriptor
                ).coverage
            )
        case .kernel(let input, _, let filter):
            return SamplerExecutionAdapter.merge(
                try input.resolvedSamplerExecutionCoverage(
                    profile: profile,
                    samplerDescriptor: samplerDescriptor
                ),
                SamplerExecutionAdapter.makePlan(
                    filters: [filter],
                    samplerDescriptor: samplerDescriptor
                ).coverage
            )
        case .cachePolicy(let input, _):
            return try input.resolvedSamplerExecutionCoverage(
                profile: profile,
                samplerDescriptor: samplerDescriptor
            )
        case .samplerDescriptor(let input, let descriptor):
            return try input.resolvedSamplerExecutionCoverage(
                profile: profile,
                samplerDescriptor: descriptor
            )
        case .edit, .transition, .layerComposite:
            return try makeRenderPlan(
                profile: profile,
                derivative: profile.defaultDerivativeSpec,
                samplerDescriptorOverride: samplerDescriptor
            ).diagnostics.samplerExecutionCoverage
        }
    }

    fileprivate func resolvedFrameColorSpace(for source: ImageSource, outputColorSpace: ImageColorSpaceContract) -> CGColorSpace? {
        if outputColorSpace.preservesInput == false, let colorSpace = outputColorSpace.cgColorSpace {
            return colorSpace
        }
        if let colorSpace = source.colorSpace { return colorSpace }
        let sourceDescriptor = source.descriptor
        if let colorSpace = sourceDescriptor.pixelBufferContract?.attachmentColorSpace?.cgColorSpace {
            return colorSpace
        }
        if let colorSpace = sourceDescriptor.sampleBufferContract?.pixelBufferContract?.attachmentColorSpace?.cgColorSpace {
            return colorSpace
        }
        return nil
    }

    fileprivate func makePreviewHostPayload(
        source: ImageSource,
        renderedTexture: MTLTexture,
        renderRecipe: RenderRecipe
    ) -> RenderedFramePreviewHostPayload? {
        guard case .sampleBuffer(let sampleBuffer) = source else { return nil }
        let sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let sourceWidth = sourceImageBuffer.map(CVPixelBufferGetWidth)
        let sourceHeight = sourceImageBuffer.map(CVPixelBufferGetHeight)
        let preservesDisplaySemantics = renderRecipe.filters.isEmpty && sourceWidth == renderedTexture.width && sourceHeight == renderedTexture.height
        let referenceSampleBuffer = sampleBuffer.c7.makeLightweightReferenceSampleBuffer()
        if let referencePixelBuffer = referenceSampleBuffer.flatMap(CMSampleBufferGetImageBuffer),
           referencePixelBuffer.c7.textureCopyCompatibilityError(for: renderedTexture) != nil {
            return nil
        }
        if preservesDisplaySemantics {
            return RenderedFramePreviewHostPayload(passthroughSampleBuffer: referenceSampleBuffer)
        }
        return RenderedFramePreviewHostPayload(sampleBufferFactory: {
            try Self.makePreviewHostRematerializedSampleBuffer(
                texture: renderedTexture,
                referenceSampleBuffer: referenceSampleBuffer ?? sampleBuffer
            )
        })
    }

    fileprivate func resolvedPreviewHostStrategy(
        source: ImageSource,
        renderedTexture: MTLTexture,
        renderRecipe: RenderRecipe
    ) -> PreviewHostStrategy {
        guard case .sampleBuffer(let sampleBuffer) = source else { return .metalTextureHost }
        let sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let sourceWidth = sourceImageBuffer.map(CVPixelBufferGetWidth)
        let sourceHeight = sourceImageBuffer.map(CVPixelBufferGetHeight)
        let preservesDisplaySemantics = renderRecipe.filters.isEmpty && sourceWidth == renderedTexture.width && sourceHeight == renderedTexture.height
        return preservesDisplaySemantics ? .sampleBufferPassthroughHost : .sampleBufferRematerializedHost
    }

    fileprivate static func makePreviewHostRematerializedSampleBuffer(texture: MTLTexture, referenceSampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer? {
        let referencePixelBuffer = CMSampleBufferGetImageBuffer(referenceSampleBuffer)
        let referenceFormatType = referencePixelBuffer.map(CVPixelBufferGetPixelFormatType)
        let resolvedFormatType: OSType
        if let referencePixelBuffer, referencePixelBuffer.c7.contract.planar == false,
           let preferredType = RenderPixelBufferDescriptor.pixelFormatType(for: texture.pixelFormat),
           preferredType == referenceFormatType {
            resolvedFormatType = preferredType
        } else if let fallbackType = RenderPixelBufferDescriptor.pixelFormatType(for: texture.pixelFormat) {
            resolvedFormatType = fallbackType
        } else {
            resolvedFormatType = kCVPixelFormatType_32BGRA
        }
        let acquisition = try PixelBufferPool.acquire(
            for: RenderPixelBufferDescriptor(
                width: texture.width,
                height: texture.height,
                pixelFormatType: resolvedFormatType,
                minimumBufferCount: 1
            ),
            realtime: true
        )
        let pixelBuffer = acquisition.buffer
        if let compatibilityError = pixelBuffer.c7.textureCopyCompatibilityError(for: texture) {
            throw compatibilityError
        }
        guard pixelBuffer.c7.copyToPixelBuffer(with: texture) else {
            throw HarbethError.pixelBufferCopyFailed
        }
        if let imageBuffer = referencePixelBuffer {
            pixelBuffer.c7.copyAttachments(from: imageBuffer)
        }
        return pixelBuffer.c7.toCMSampleBuffer(reference: referenceSampleBuffer)
    }

    func resolvedPlanningOutputSizeHint(profile: RenderProfile) -> C7Size? {
        switch storage {
        case .source(let source):
            return source.resolvedSizeHint
        case .filters(let input, let filters):
            guard let inputSize = input.resolvedPlanningOutputSizeHint(profile: profile) else {
                return nil
            }
            return filters.reduce(inputSize) { size, filter in
                filter.resize(input: size)
            }
        case .kernel(let input, _, let filter):
            guard let inputSize = input.resolvedPlanningOutputSizeHint(profile: profile) else {
                return nil
            }
            return filter.resize(input: inputSize)
        case .edit, .transition, .layerComposite:
            return nil
        case .cachePolicy(let input, _), .samplerDescriptor(let input, _):
            return input.resolvedPlanningOutputSizeHint(profile: profile)
        }
    }

    static func filterNodeFingerprint(inputFingerprint: String, filters: [C7FilterProtocol]) -> String {
        ["filters", inputFingerprint, filters.chainRecipe.fingerprint].joined(separator: "|")
    }

    var nodeFingerprint: String {
        switch storage {
        case .source(let source):
            return "source|\(source.resolutionFingerprint)"
        case .filters:
            let route = groupedFilterRoute()
            var components = Array(repeating: "filters", count: route.groups.count)
            components.append(route.input.nodeFingerprint)
            components.append(contentsOf: route.groups.reversed().map { $0.chainRecipe.fingerprint })
            return components.joined(separator: "|")
        case .kernel(let input, let descriptor, let filter):
            return [
                "kernel",
                input.nodeFingerprint,
                descriptor.fingerprint,
                filter.recipeDescriptor.fingerprint
            ].joined(separator: "|")
        case .edit(let input, let recipe, let mode):
            let planning = recipe.planningDescriptor(for: mode)
            return [
                "edit",
                input.nodeFingerprint,
                "mode=\(mode.rawValue)",
                planning.fingerprint
            ].joined(separator: "|")
        case .transition(let recipe):
            return [
                "transition",
                recipe.from.resolutionFingerprint,
                recipe.to.resolutionFingerprint,
                recipe.kernel.fingerprint,
                "progress=\(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), recipe.progress))",
                recipe.derivative.fingerprint,
            ].joined(separator: "|")
        case .layerComposite(let recipe):
            return [
                "layerComposite",
                recipe.background.resolutionFingerprint,
                recipe.layers.map { $0.content.resolutionFingerprint + "|" + $0.fingerprint }.joined(separator: "||"),
                recipe.fingerprint,
            ].joined(separator: "|")
        case .cachePolicy(let input, let policy):
            return "\(input.nodeFingerprint)|cacheOverride=\(policy.rawValue)"
        case .samplerDescriptor(let input, let descriptor):
            return "\(input.nodeFingerprint)|samplerOverride=\(descriptor.fingerprint)"
        }
    }

    func resolvedPrimarySource() throws -> ImageSource {
        switch storage {
        case .source(let source):
            return source
        case .filters(let input, _), .kernel(let input, _, _), .cachePolicy(let input, _), .samplerDescriptor(let input, _):
            return try input.resolvedPrimarySource()
        case .edit(let input, _, _):
            return try input.resolvedPrimarySource()
        case .transition(let recipe):
            return recipe.from
        case .layerComposite(let recipe):
            return recipe.background
        }
    }

    private func prepareAttachmentRoute(profile: RenderProfile) throws -> PreparedImageNodeAttachmentRoute? {
        guard let specification = resolvedAttachmentRouteSpecification() else { return nil }
        let inputExecution = try specification.input.prepareExecution(
            profile: profile,
            derivative: profile.defaultDerivativeSpec,
            executionIdentifier: "ImageNode.PreparedAttachment",
            samplerDescriptorOverride: specification.samplerDescriptor
        )
        return PreparedImageNodeAttachmentRoute(
            inputExecution: inputExecution,
            filter: specification.filter,
            validateInput: specification.validateInput
        )
    }

    private func resolvedAttachmentRouteSpecification() -> (
        input: ImageNode,
        filter: any RenderProtocol,
        samplerDescriptor: ImageSamplerDescriptor,
        validateInput: (MTLTexture) throws -> Void
    )? {
        switch storage {
        case .filters(let input, let filters):
            guard let finalFilter = filters.last as? any RenderProtocol else { return nil }
            let routeInput = filters.count > 1
                ? ImageNode.filters(input: input, filters: Array(filters.dropLast()))
                : input
            return (routeInput, finalFilter, resolvedSamplerDescriptor, { _ in })
        case .kernel(let input, let descriptor, let filter):
            guard let renderFilter = filter as? any RenderProtocol else { return nil }
            return (
                input,
                renderFilter,
                resolvedSamplerDescriptor,
                { texture in
                    try descriptor.validateCompatibility(with: filter, inputSize: C7Size(texture: texture))
                }
            )
        case .cachePolicy(let input, _):
            return input.resolvedAttachmentRouteSpecification()
        case .samplerDescriptor(let input, let descriptor):
            guard let route = input.resolvedAttachmentRouteSpecification() else { return nil }
            return (
                route.input,
                SamplerExecutionAdapter.adapt(renderFilter: route.filter, samplerDescriptor: descriptor),
                descriptor,
                route.validateInput
            )
        case .source, .edit, .transition, .layerComposite:
            return nil
        }
    }

    private func makeWrappedEditRenderPlan(
        source: ImageSource,
        inputSize: C7Size,
        recipe: EditRecipe,
        mode: EditRecipeMode,
        extraFilters: [C7FilterProtocol],
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        samplerDescriptor: ImageSamplerDescriptor,
        sourceDescriptor: ImageSourceDescriptor,
        optimization: ImageGraphOptimizationResult,
        upstreamContract: RenderOutputContract? = nil
    ) throws -> RenderPlan {
        let plan = try recipe.makeRenderPlan(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative,
            samplerDescriptor: samplerDescriptor,
            inputSize: inputSize
        )
        return RenderPlan(
            graph: plan.graph,
            profile: plan.profile,
            derivative: plan.diagnostics.derivative,
            inputSize: plan.diagnostics.inputSize,
            outputSize: plan.diagnostics.outputSize,
            nodeDiagnostics: plan.diagnostics.nodes,
            compilationSource: plan.diagnostics.compilationSource,
            outputContract: GraphCompiler.resolveOutputContract(plan.diagnostics.outputContract, preserving: upstreamContract ?? .preserveInput),
            imageCachePolicy: plan.diagnostics.imageCachePolicy,
            samplerDescriptor: plan.diagnostics.samplerDescriptor,
            samplerExecutionCoverage: plan.diagnostics.samplerExecutionCoverage,
            sourceDescriptor: sourceDescriptor,
            inputColorConversionCount: plan.diagnostics.inputColorConversionCount,
            inputPixelFormatConversionCount: plan.diagnostics.inputPixelFormatConversionCount,
            inputAlphaConversionCount: plan.diagnostics.inputAlphaConversionCount,
            imageGraph: optimization.graph,
            graphOptimizationDecisions: optimization.decisions
        )
    }
}

private extension RenderRecipe {
    func appending(filterDescriptors: [FilterRecipeDescriptor], derivative: ImageDerivativeSpec? = nil) -> RenderRecipe {
        RenderRecipe(
            renderProfile: renderProfile,
            renderIntent: derivative?.renderIntent ?? renderIntent,
            source: source,
            outputDerivative: derivative ?? outputDerivative,
            outputCachePolicy: outputCachePolicy,
            outputSemantic: derivative?.semantic ?? outputSemantic,
            alphaType: alphaType,
            orientation: orientation,
            filters: filters + filterDescriptors,
            localEffects: localEffects,
            layerMasks: layerMasks,
            upstreamProcessingFingerprint: upstreamProcessingFingerprint
        )
    }

    func with(outputCachePolicy: ImageCachePolicy) -> RenderRecipe {
        RenderRecipe(
            renderProfile: renderProfile,
            renderIntent: renderIntent,
            source: source,
            outputDerivative: outputDerivative,
            outputCachePolicy: outputCachePolicy,
            outputSemantic: outputSemantic,
            alphaType: alphaType,
            orientation: orientation,
            filters: filters,
            localEffects: localEffects,
            layerMasks: layerMasks,
            upstreamProcessingFingerprint: upstreamProcessingFingerprint
        )
    }
}

extension ImageNode {
    static func applyOutputContractIfNeeded(
        _ contract: RenderOutputContract,
        to texture: MTLTexture,
        sourceColorSpace: ImageColorSpaceContract = .preserveInput,
        sourceAlphaType: AlphaType? = nil,
        profile: RenderProfile,
        identifier: String? = nil
    ) throws -> MTLTexture {
        let cacheKey = makeOutputContractCacheKey(
            contract: contract,
            inputTexture: texture,
            sourceColorSpace: sourceColorSpace,
            sourceAlphaType: sourceAlphaType,
            profile: profile
        )
        let context = HarbethContext.shared
        let cacheIdentity = cacheKey.isEffective
            ? context.makeDerivedResourceIdentity(domain: .outputContract, fingerprint: cacheKey.key)
            : nil
        if let cacheIdentity,
           let cached = context.cachedDerivedObject(for: cacheIdentity) as? OutputContractCacheEntry,
           cached.sourceTexture === texture as AnyObject {
            return cached.outputTexture
        }

        var output = texture
        let toneMappingFilters = contract.toneMappingPolicy.makeToneMappingFilters(
            sourceColorSpace: sourceColorSpace,
            targetColorSpace: contract.colorSpace
        )
        let colorFilters = contract.colorSpace.makeColorConversionFilters(from: sourceColorSpace)
        if toneMappingFilters.isEmpty == false {
            if let first = colorFilters.first as? C7RGBTransferConversion, first.mode.isDecodeTransfer {
                output = try HarbethIO(
                    element: output,
                    filters: [first],
                    identifier: identifier ?? "ImageNode.OutputContract"
                ).configured(for: profile).output()
                output = try HarbethIO(
                    element: output,
                    filters: toneMappingFilters,
                    identifier: identifier ?? "ImageNode.OutputContract"
                ).configured(for: profile).output()
                if colorFilters.count > 1 {
                    output = try HarbethIO(
                        element: output,
                        filters: Array(colorFilters.dropFirst()),
                        identifier: identifier ?? "ImageNode.OutputContract"
                    ).configured(for: profile).output()
                }
            } else {
                output = try HarbethIO(
                    element: output,
                    filters: toneMappingFilters,
                    identifier: identifier ?? "ImageNode.OutputContract"
                ).configured(for: profile).output()
                if colorFilters.isEmpty == false {
                    output = try HarbethIO(
                        element: output,
                        filters: colorFilters,
                        identifier: identifier ?? "ImageNode.OutputContract"
                    ).configured(for: profile).output()
                }
            }
        } else if colorFilters.isEmpty == false {
            output = try HarbethIO(
                element: output,
                filters: colorFilters,
                identifier: identifier ?? "ImageNode.OutputContract"
            ).configured(for: profile).output()
        }
        let filters: [C7FilterProtocol]
        switch contract.alpha {
        case .premultiplied, .forcePremultiply:
            filters = sourceAlphaType == .premultiplied ? [] : [C7PremultiplyAlpha()]
        case .nonPremultiplied, .forceUnpremultiply:
            filters = sourceAlphaType == .nonPremultiplied ? [] : [C7UnpremultiplyAlpha()]
        case .opaque:
            filters = sourceAlphaType == .alphaIsOne ? [] : [C7ForceOpaqueAlpha()]
        case .preserveInput:
            filters = []
        }
        if filters.isEmpty == false {
            output = try HarbethIO(
                element: output,
                filters: filters,
                identifier: identifier ?? "ImageNode.OutputContract"
            ).configured(for: profile).output()
        }
        if contract.quantization.shouldApply(sourcePixelFormat: output.pixelFormat, target: contract.pixelFormat) {
            output = try HarbethIO(
                element: output,
                filter: C7OutputQuantization(contract: contract.quantization),
                identifier: identifier ?? "ImageNode.OutputContract"
            ).configured(for: profile).output()
        }
        if let targetPixelFormat = contract.pixelFormat.metalPixelFormat, output.pixelFormat != targetPixelFormat {
            var io = HarbethIO(
                element: output,
                filter: C7PixelFormatChange(),
                identifier: identifier ?? "ImageNode.OutputContract"
            ).configured(for: profile)
            io.bufferPixelFormat = targetPixelFormat
            output = try io.output()
        }
        let didProduceNewTexture = output !== texture
        if let cacheIdentity, didProduceNewTexture {
            context.storeDerivedObject(
                OutputContractCacheEntry(sourceTexture: texture, outputTexture: output),
                byteCost: max(output.allocatedSize, 1),
                for: cacheIdentity
            )
        }
        return output
    }

    /// 输出 contract 缓存键。
    /// 组成:`contract.fingerprint` + `inputTexture` 的
    /// `ObjectIdentifier + width × height × pixelFormat`。
    /// `ObjectIdentifier` 让 cache 在纹理被释放后自动失配(下次 miss 重建),
    /// 不会跨 texture 误命中。
    private static func makeOutputContractCacheKey(
        contract: RenderOutputContract,
        inputTexture: MTLTexture,
        sourceColorSpace: ImageColorSpaceContract,
        sourceAlphaType: AlphaType?,
        profile: RenderProfile
    ) -> (key: String, isEffective: Bool) {
        let inputFingerprint = "tex|\(ObjectIdentifier(inputTexture).hashValue)|\(inputTexture.width)x\(inputTexture.height)|\(inputTexture.pixelFormat.rawValue)"
        let key = [
            "contract=\(contract.fingerprint)",
            "srcColorSpace=\(sourceColorSpace.fingerprint)",
            "srcAlpha=\(sourceAlphaType.map(String.init(describing:)) ?? "nil")",
            "profile=\(profile.rawValue)",
            inputFingerprint
        ].joined(separator: "||")
        let needsColor = !contract.colorSpace.makeColorConversionFilters(from: sourceColorSpace).isEmpty
        let needsToneMapping = !contract.toneMappingPolicy.makeToneMappingFilters(
            sourceColorSpace: sourceColorSpace,
            targetColorSpace: contract.colorSpace
        ).isEmpty
        let needsAlpha: Bool
        switch contract.alpha {
        case .premultiplied, .forcePremultiply:
            needsAlpha = sourceAlphaType != .premultiplied
        case .nonPremultiplied, .forceUnpremultiply:
            needsAlpha = sourceAlphaType != .nonPremultiplied
        case .opaque:
            needsAlpha = sourceAlphaType != .alphaIsOne
        case .preserveInput:
            needsAlpha = false
        }
        let needsPixelFormat: Bool
        if let targetPixelFormat = contract.pixelFormat.metalPixelFormat {
            needsPixelFormat = inputTexture.pixelFormat != targetPixelFormat
        } else {
            needsPixelFormat = false
        }
        let needsQuantization = contract.quantization.shouldApply(
            sourcePixelFormat: inputTexture.pixelFormat,
            target: contract.pixelFormat
        )
        let isEffective = needsColor || needsToneMapping || needsAlpha || needsQuantization || needsPixelFormat
        return (key, isEffective)
    }
}
