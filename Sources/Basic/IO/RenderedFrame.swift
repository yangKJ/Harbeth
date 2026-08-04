//
//  RenderedFrame.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
@preconcurrency import Metal
import CoreGraphics
import CoreVideo
import CoreMedia

/// 附加在渲染纹理帧上的方向元数据。
public enum FrameOrientation: String, Sendable, Equatable, Codable {
    case up
    case down
    case left
    case right
    case upMirrored
    case downMirrored
    case leftMirrored
    case rightMirrored
    case unknown
}

/// 渲染输出档位。档位描述调度和读回语义，
/// 不描述视觉滤镜参数。
public enum RenderProfile: String, Sendable, Codable, Equatable, Hashable {
    /// 面向高频交互回路的最低延迟纹理输出。
    case interactiveLatency
    /// 面向离散参数变更的快速首帧反馈。
    case responseLatency
    /// 默认稳定显示路径使用的中等成本输出档位。
    case stablePreview
    /// 面向静态检查和高保真查看的输出档位。
    case inspectionQuality
    /// 面向最终交付资源生成的输出档位。
    case exportQuality
    /// 明确需要 CPU 读回 image/data 的输出路径。
    case readbackQuality

    public var usesRealTimeCommit: Bool {
        switch self {
        case .interactiveLatency:
            return true
        case .responseLatency, .stablePreview, .inspectionQuality, .exportQuality, .readbackQuality:
            return false
        }
    }

    public var enablesDoubleBuffer: Bool {
        switch self {
        case .interactiveLatency:
            return false
        case .responseLatency, .stablePreview, .inspectionQuality, .exportQuality, .readbackQuality:
            return true
        }
    }

    public var createsDestinationTexture: Bool {
        switch self {
        case .interactiveLatency:
            return false
        case .responseLatency, .stablePreview, .inspectionQuality, .exportQuality, .readbackQuality:
            return true
        }
    }

    public var requiresCompletedGPUWorkBeforeReadback: Bool {
        switch self {
        case .readbackQuality, .exportQuality:
            return true
        case .interactiveLatency, .responseLatency, .stablePreview, .inspectionQuality:
            return false
        }
    }
}

/// 单次帧渲染请求的稳定标识。generation 在请求创建时分配，
/// 用于 UI 层丢弃较早请求的迟到结果。
public struct FrameRenderToken: Sendable, Equatable {
    public let identifier: String
    public let generation: UInt64

    public init(identifier: String, generation: UInt64) {
        self.identifier = identifier
        self.generation = generation
    }

    public func isOlder(than token: FrameRenderToken) -> Bool {
        guard identifier == token.identifier else { return false }
        return generation < token.generation
    }
}

enum PreviewHostStrategy: String, Sendable, Codable, Equatable, Hashable {
    case metalTextureHost
    case sampleBufferPassthroughHost
    case sampleBufferRematerializedHost
}

enum PreviewHostRecoveryPolicy: String, Sendable, Codable, Equatable, Hashable {
    case flushThenFallbackToMetal
}

struct PreviewHostStrategyResolution: Sendable, Equatable, Hashable {
    let strategy: PreviewHostStrategy
    let sampleBufferHostEligible: Bool
    let sampleBufferHostPayloadAvailable: Bool
    let sampleBufferHostRequiresRematerialization: Bool
    let recoveryPolicy: PreviewHostRecoveryPolicy
    let hostRecoveredByFlush: Bool
    let hostFellBackToMetal: Bool
}

final class RenderedFramePreviewHostPayload: @unchecked Sendable {
    let passthroughSampleBuffer: CMSampleBuffer?
    private let sampleBufferFactory: (() throws -> CMSampleBuffer?)?

    init(passthroughSampleBuffer: CMSampleBuffer? = nil, sampleBufferFactory: (() throws -> CMSampleBuffer?)? = nil) {
        self.passthroughSampleBuffer = passthroughSampleBuffer
        self.sampleBufferFactory = sampleBufferFactory
    }

    var supportsPassthrough: Bool {
        passthroughSampleBuffer != nil
    }

    var supportsRematerialization: Bool {
        sampleBufferFactory != nil
    }

    func makeSampleBuffer() throws -> CMSampleBuffer? {
        if let passthroughSampleBuffer {
            return passthroughSampleBuffer
        }
        return try sampleBufferFactory?()
    }
}

/// texture-first 渲染结果的稳定元数据包装。
public struct RenderedFrame: @unchecked Sendable {
    public let texture: MTLTexture
    public let size: CGSize
    public let pixelFormat: MTLPixelFormat
    public let colorSpace: CGColorSpace?
    public let outputColorSpaceContract: ImageColorSpaceContract
    public let outputDynamicRange: ImageDynamicRangeContract
    public let outputToneMappingPolicy: ImageToneMappingPolicy
    public let sourceDescriptor: ImageSourceDescriptor
    public let derivative: ImageDerivativeSpec
    public let resolvedOutputSize: C7Size
    public let renderIntent: RenderIntent
    public let sourceTier: ImageSourceTier
    public let alphaType: AlphaType
    public let cachePolicy: ImageCachePolicy
    public let semantic: ImageSemanticDescriptor
    public let orientation: FrameOrientation
    public let profile: RenderProfile
    public let generation: UInt64
    public let identifier: String
    public let token: FrameRenderToken
    public let metadata: [String: String]
    /// Optional texture lifetime handle. A frame keeps this strongly so advanced
    /// callers can bind texture ownership to a host-managed display lifetime.
    public let lease: TextureLease?
    let previewHostPayload: RenderedFramePreviewHostPayload?

    public init(texture: MTLTexture,
                colorSpace: CGColorSpace? = nil,
                outputColorSpaceContract: ImageColorSpaceContract? = nil,
                outputToneMappingPolicy: ImageToneMappingPolicy = .preserveInput,
                sourceDescriptor: ImageSourceDescriptor? = nil,
                derivative: ImageDerivativeSpec? = nil,
                resolvedOutputSize: C7Size? = nil,
                renderIntent: RenderIntent? = nil,
                sourceTier: ImageSourceTier = .original,
                alphaType: AlphaType = .premultiplied,
                cachePolicy: ImageCachePolicy = .transient,
                semantic: ImageSemanticDescriptor? = nil,
                orientation: FrameOrientation = .up,
                profile: RenderProfile,
                generation: UInt64,
                identifier: String,
                metadata: [String: String] = [:],
                lease: TextureLease? = nil) {
        let token = FrameRenderToken(identifier: identifier, generation: generation)
        self.init(
            texture: texture,
            colorSpace: colorSpace,
            outputColorSpaceContract: outputColorSpaceContract,
            outputToneMappingPolicy: outputToneMappingPolicy,
            sourceDescriptor: sourceDescriptor,
            derivative: derivative,
            resolvedOutputSize: resolvedOutputSize,
            renderIntent: renderIntent,
            sourceTier: sourceTier,
            alphaType: alphaType,
            cachePolicy: cachePolicy,
            semantic: semantic,
            orientation: orientation,
            profile: profile,
            token: token,
            metadata: metadata,
            lease: lease
        )
    }

    public init(texture: MTLTexture,
                colorSpace: CGColorSpace? = nil,
                outputColorSpaceContract: ImageColorSpaceContract? = nil,
                outputToneMappingPolicy: ImageToneMappingPolicy = .preserveInput,
                sourceDescriptor: ImageSourceDescriptor? = nil,
                derivative: ImageDerivativeSpec? = nil,
                resolvedOutputSize: C7Size? = nil,
                renderIntent: RenderIntent? = nil,
                sourceTier: ImageSourceTier = .original,
                alphaType: AlphaType = .premultiplied,
                cachePolicy: ImageCachePolicy = .transient,
                semantic: ImageSemanticDescriptor? = nil,
                orientation: FrameOrientation = .up,
                profile: RenderProfile,
                token: FrameRenderToken,
                metadata: [String: String] = [:],
                lease: TextureLease? = nil) {
        self.init(
            texture: texture,
            colorSpace: colorSpace,
            outputColorSpaceContract: outputColorSpaceContract,
            outputToneMappingPolicy: outputToneMappingPolicy,
            sourceDescriptor: sourceDescriptor,
            derivative: derivative,
            resolvedOutputSize: resolvedOutputSize,
            renderIntent: renderIntent,
            sourceTier: sourceTier,
            alphaType: alphaType,
            cachePolicy: cachePolicy,
            semantic: semantic,
            orientation: orientation,
            profile: profile,
            token: token,
            metadata: metadata,
            lease: lease,
            previewHostPayload: nil
        )
    }

    init(texture: MTLTexture,
         colorSpace: CGColorSpace? = nil,
         outputColorSpaceContract: ImageColorSpaceContract? = nil,
         outputToneMappingPolicy: ImageToneMappingPolicy = .preserveInput,
         sourceDescriptor: ImageSourceDescriptor? = nil,
         derivative: ImageDerivativeSpec? = nil,
         resolvedOutputSize: C7Size? = nil,
         renderIntent: RenderIntent? = nil,
         sourceTier: ImageSourceTier = .original,
         alphaType: AlphaType = .premultiplied,
         cachePolicy: ImageCachePolicy = .transient,
         semantic: ImageSemanticDescriptor? = nil,
         orientation: FrameOrientation = .up,
         profile: RenderProfile,
         token: FrameRenderToken,
         metadata: [String: String] = [:],
         lease: TextureLease? = nil,
         previewHostPayload: RenderedFramePreviewHostPayload? = nil) {
        self.texture = texture
        self.size = CGSize(
            width: resolvedOutputSize?.width ?? texture.width,
            height: resolvedOutputSize?.height ?? texture.height
        )
        self.pixelFormat = texture.pixelFormat
        self.colorSpace = colorSpace
        let resolvedColorSpaceContract = outputColorSpaceContract
            ?? colorSpace.map(ImageColorSpaceContract.init(colorSpace:))
            ?? .preserveInput
        self.outputColorSpaceContract = resolvedColorSpaceContract
        self.outputDynamicRange = resolvedColorSpaceContract.dynamicRange
        self.outputToneMappingPolicy = outputToneMappingPolicy
        self.sourceDescriptor = sourceDescriptor ?? ImageSourceDescriptor(
            kind: "texture",
            sourceTier: sourceTier,
            alphaType: alphaType,
            orientation: orientation,
            cachePolicy: cachePolicy,
            semantic: .sourceOriginal,
            loadingOptions: .default
        )
        let resolvedDerivative = derivative ?? profile.defaultDerivativeSpec
        self.derivative = resolvedDerivative
        self.resolvedOutputSize = resolvedOutputSize ?? C7Size(texture: texture)
        self.renderIntent = renderIntent ?? profile.defaultRenderIntent
        self.sourceTier = sourceTier
        self.alphaType = alphaType
        self.cachePolicy = cachePolicy
        self.semantic = semantic ?? profile.defaultImageSemantic
        self.orientation = orientation
        self.profile = profile
        self.generation = token.generation
        self.identifier = token.identifier
        self.token = token
        self.metadata = metadata
        self.lease = lease
        self.previewHostPayload = previewHostPayload
    }

    public func isCurrent(comparedTo latestToken: FrameRenderToken) -> Bool {
        guard identifier == latestToken.identifier else { return true }
        return generation >= latestToken.generation
    }

    public var replayBaseContract: ReplayBaseContract {
        derivative.replayBaseContract
    }

    public var frameHostSourceDescriptor: FrameHostSourceDescriptor {
        let sourceHost = sourceDescriptor.frameHostSourceDescriptor
        guard sourceHost.frameSize.width > 0, sourceHost.frameSize.height > 0 else {
            return FrameHostSourceDescriptor(
                frameSize: C7Size(texture: texture),
                orientation: orientation,
                mirrorHorizontally: sourceHost.mirrorHorizontally,
                mirrorVertically: sourceHost.mirrorVertically,
                followsDeviceOrientation: sourceHost.followsDeviceOrientation,
                directPlaneBridgeCount: sourceHost.directPlaneBridgeCount,
                bridgePolicy: sourceHost.bridgePolicy,
                yCbCrDecodeContract: sourceHost.yCbCrDecodeContract,
                metadataCompleteness: FrameHostMetadataCompleteness(
                    hasFrameSize: true,
                    hasOrientation: sourceHost.metadataCompleteness.hasOrientation,
                    hasMirror: sourceHost.metadataCompleteness.hasMirror,
                    hasDeviceOrientation: sourceHost.metadataCompleteness.hasDeviceOrientation,
                    hasTiming: sourceHost.metadataCompleteness.hasTiming,
                    hasSampleAttachments: sourceHost.metadataCompleteness.hasSampleAttachments
                )
            )
        }
        return sourceHost
    }

    public var frameHostRuntimeHint: FrameHostRuntimeHint {
        FrameHostRuntimeHint(source: frameHostSourceDescriptor, profile: profile)
    }

    var previewHostStrategyResolution: PreviewHostStrategyResolution {
        if metadata["previewHostStrategy"] == PreviewHostStrategy.metalTextureHost.rawValue {
            return PreviewHostStrategyResolution(
                strategy: .metalTextureHost,
                sampleBufferHostEligible: false,
                sampleBufferHostPayloadAvailable: previewHostPayload != nil,
                sampleBufferHostRequiresRematerialization: false,
                recoveryPolicy: .flushThenFallbackToMetal,
                hostRecoveredByFlush: false,
                hostFellBackToMetal: false
            )
        }
        let eligible = sourceDescriptor.kind == "sampleBuffer" && frameHostRuntimeHint.isRealtimePreviewEligible
        let payloadAvailable = previewHostPayload != nil
        let requiresRematerialization = previewHostPayload?.supportsPassthrough == false && previewHostPayload?.supportsRematerialization == true
        let strategy: PreviewHostStrategy
        if eligible == false || payloadAvailable == false {
            strategy = .metalTextureHost
        } else if requiresRematerialization {
            strategy = .sampleBufferRematerializedHost
        } else {
            strategy = .sampleBufferPassthroughHost
        }
        return PreviewHostStrategyResolution(
            strategy: strategy,
            sampleBufferHostEligible: eligible,
            sampleBufferHostPayloadAvailable: payloadAvailable,
            sampleBufferHostRequiresRematerialization: requiresRematerialization,
            recoveryPolicy: .flushThenFallbackToMetal,
            hostRecoveredByFlush: false,
            hostFellBackToMetal: false
        )
    }

    func makePreviewHostSampleBuffer() throws -> CMSampleBuffer? {
        try previewHostPayload?.makeSampleBuffer()
    }

    public var cacheIdentity: RenderCacheIdentity {
        RenderCacheIdentity(
            sourceFingerprint: sourceDescriptor.fingerprint,
            renderIntent: renderIntent,
            derivativeFingerprint: derivative.fingerprint,
            replayBaseFingerprint: replayBaseContract.fingerprint,
            filterChainFingerprint: metadata["filterChainFingerprint"] ?? ""
        )
    }

    public var textureSize: CGSize {
        CGSize(width: texture.width, height: texture.height)
    }

    public var sourcePixelSize: CGSize {
        let sourceSize = frameHostSourceDescriptor.frameSize
        guard sourceSize.width > 0, sourceSize.height > 0 else { return size }
        return CGSize(width: sourceSize.width, height: sourceSize.height)
    }

    public var displaySize: CGSize { size }

    public var outputImageSize: CGSize { size }

    public func makeImage(colorSpace: CGColorSpace? = nil) throws -> C7Image? {
        texture.c7.toImage(colorSpace: colorSpace ?? self.colorSpace)
    }
}

/// 高级渲染流程的终端输出意图。
enum RenderTarget: Sendable, Equatable {
    case texture
    case frame
    case image
    case pixelBuffer
    case data
}

struct PreparedFrameTextureExecution: @unchecked Sendable {
    let source: ImageSource
    let diagnosticFilters: [C7FilterProtocol]
    let resolvedOutputSize: C7Size
    private let renderTextureClosure: () throws -> MTLTexture

    init(source: ImageSource,
         diagnosticFilters: [C7FilterProtocol],
         resolvedOutputSize: C7Size,
         renderTexture: @escaping () throws -> MTLTexture) {
        self.source = source
        self.diagnosticFilters = diagnosticFilters
        self.resolvedOutputSize = resolvedOutputSize
        self.renderTextureClosure = renderTexture
    }

    func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }
}

/// 面向产品级调用方的 texture-first 渲染器，提供稳定帧元数据。
struct FrameRenderer: @unchecked Sendable {
    let source: ImageSource
    let filters: [C7FilterProtocol]
    let recipe: EditRecipe?
    let recipeMode: EditRecipeMode?
    let transitionRecipe: TransitionRecipe?
    let samplerDescriptor: ImageSamplerDescriptor
    let outputColorSpace: ImageColorSpaceContract?
    let outputToneMappingPolicy: ImageToneMappingPolicy?
    var profile: RenderProfile
    var renderIntent: RenderIntent
    var identifier: String
    var metadata: [String: String]
    var outputCachePolicy: ImageCachePolicy
    var outputSemantic: ImageSemanticDescriptor
    var outputDerivative: ImageDerivativeSpec

    init(source: ImageSource,
         filters: [C7FilterProtocol] = [],
         profile: RenderProfile = .stablePreview,
         renderIntent: RenderIntent? = nil,
         identifier: String = UUID().uuidString,
         metadata: [String: String] = [:],
         outputColorSpace: ImageColorSpaceContract? = nil,
         outputToneMappingPolicy: ImageToneMappingPolicy? = nil,
         outputSemantic: ImageSemanticDescriptor? = nil,
         outputDerivative: ImageDerivativeSpec? = nil,
         outputCachePolicy: ImageCachePolicy? = nil,
         samplerDescriptor: ImageSamplerDescriptor = .default) {
        self.source = source
        self.filters = filters
        self.recipe = nil
        self.recipeMode = nil
        self.transitionRecipe = nil
        self.samplerDescriptor = samplerDescriptor
        self.outputColorSpace = outputColorSpace
        self.outputToneMappingPolicy = outputToneMappingPolicy
        self.profile = profile
        self.renderIntent = renderIntent ?? profile.defaultRenderIntent
        self.identifier = identifier
        self.metadata = metadata
        self.outputCachePolicy = outputCachePolicy ?? (filters.isEmpty ? source.cachePolicy : .transient)
        self.outputSemantic = outputSemantic ?? profile.defaultImageSemantic
        self.outputDerivative = outputDerivative ?? profile.defaultDerivativeSpec
    }

    init(source: ImageSource,
         recipe: EditRecipe,
         mode: EditRecipeMode = .preview,
         filters: [C7FilterProtocol] = [],
         identifier: String = UUID().uuidString,
         metadata: [String: String] = [:],
         derivative: ImageDerivativeSpec? = nil,
         outputColorSpace: ImageColorSpaceContract? = nil,
         outputToneMappingPolicy: ImageToneMappingPolicy? = nil,
         samplerDescriptor: ImageSamplerDescriptor = .default) {
        let contract = recipe.contract(for: mode)
        self.source = source
        self.filters = filters
        self.recipe = recipe
        self.recipeMode = mode
        self.transitionRecipe = nil
        self.samplerDescriptor = samplerDescriptor
        self.outputColorSpace = outputColorSpace
        self.outputToneMappingPolicy = outputToneMappingPolicy
        self.profile = contract.profile
        self.renderIntent = contract.renderIntent
        self.identifier = identifier
        self.metadata = metadata
        self.outputCachePolicy = (recipe.geometry.isIdentity && recipe.localEffects.isEmpty && filters.isEmpty) ? source.cachePolicy : .transient
        self.outputSemantic = contract.derivative.semantic
        self.outputDerivative = derivative ?? contract.derivative
    }

    init(transitionRecipe: TransitionRecipe,
         filters: [C7FilterProtocol] = [],
         profile: RenderProfile? = nil,
         derivative: ImageDerivativeSpec? = nil,
         identifier: String = UUID().uuidString,
         metadata: [String: String] = [:],
         outputColorSpace: ImageColorSpaceContract? = nil,
         outputToneMappingPolicy: ImageToneMappingPolicy? = nil,
         samplerDescriptor: ImageSamplerDescriptor = .default) {
        self.source = transitionRecipe.from
        self.filters = filters
        self.recipe = nil
        self.recipeMode = nil
        self.transitionRecipe = transitionRecipe
        self.samplerDescriptor = samplerDescriptor
        self.outputColorSpace = outputColorSpace
        self.outputToneMappingPolicy = outputToneMappingPolicy
        let effectiveProfile = profile ?? transitionRecipe.profile
        let effectiveDerivative = derivative ?? transitionRecipe.derivative
        self.profile = effectiveProfile
        self.renderIntent = effectiveDerivative.renderIntent
        self.identifier = identifier
        self.metadata = metadata
        self.outputCachePolicy = .transient
        self.outputSemantic = effectiveDerivative.semantic
        self.outputDerivative = effectiveDerivative
    }

    func renderTexture() throws -> MTLTexture {
        if let transitionRecipe {
            return try compiledTransitionExecution(transitionRecipe).renderTexture()
        }
        if let recipe, let mode = recipeMode {
            return try compiledRecipeExecution(recipe, mode: mode).renderTexture()
        }
        let input = try source.makeTexture()
        let effectiveFilters = effectiveFilters(for: C7Size(texture: input))
        guard effectiveFilters.isEmpty == false else { return input }
        return try makeIO(element: input, filters: effectiveFilters)
            .configured(for: profile)
            .output(outputColorSpace: outputColorSpace)
    }

    func prepareTextureExecution() throws -> PreparedFrameTextureExecution {
        if let transitionRecipe {
            let execution = try compiledTransitionExecution(transitionRecipe)
            return PreparedFrameTextureExecution(
                source: execution.source,
                diagnosticFilters: execution.diagnosticFilters,
                resolvedOutputSize: execution.resolvedOutputSize,
                renderTexture: execution.renderTexture
            )
        }
        if let recipe, let mode = recipeMode {
            let execution = try compiledRecipeExecution(recipe, mode: mode)
            return PreparedFrameTextureExecution(
                source: execution.source,
                diagnosticFilters: execution.diagnosticFilters,
                resolvedOutputSize: execution.resolvedOutputSize,
                renderTexture: execution.renderTexture
            )
        }
        let input = try source.makeTexture()
        let effectiveFilters = effectiveFilters(for: C7Size(texture: input))
        let resolvedOutputSize = resolvedOutputSize(for: C7Size(texture: input), filters: effectiveFilters)
        return PreparedFrameTextureExecution(
            source: source,
            diagnosticFilters: effectiveFilters,
            resolvedOutputSize: resolvedOutputSize,
            renderTexture: {
                guard effectiveFilters.isEmpty == false else { return input }
                return try makeIO(element: input, filters: effectiveFilters)
                    .configured(for: profile)
                    .output(outputColorSpace: outputColorSpace)
            }
        )
    }

    func makeToken() -> FrameRenderToken {
        FrameRenderToken(identifier: identifier, generation: FrameGeneration.next())
    }

    func renderFrame() throws -> RenderedFrame {
        return try renderFrame(token: makeToken())
    }

    func renderFrame(token: FrameRenderToken) throws -> RenderedFrame {
        if let transitionRecipe {
            let execution = try compiledTransitionExecution(transitionRecipe)
            return try renderFrame(
                token: token,
                source: execution.source,
                renderedTexture: execution.renderTexture(),
                resolvedSize: execution.resolvedOutputSize,
                filterChain: execution.diagnosticFilters
            )
        }
        if let recipe, let mode = recipeMode {
            let execution = try compiledRecipeExecution(recipe, mode: mode)
            return try renderFrame(
                token: token,
                source: execution.source,
                renderedTexture: execution.renderTexture(),
                resolvedSize: execution.resolvedOutputSize,
                filterChain: execution.diagnosticFilters
            )
        }
        let renderedTexture: MTLTexture
        let lease: TextureLease?
        let resolvedSize: C7Size
        if filters.isEmpty {
            let input = try source.makeTexture()
            let baseSize = source.resolvedSizeHint ?? C7Size(texture: input)
            let effectiveFilters = effectiveFilters(for: baseSize)
            resolvedSize = resolvedOutputSize(for: baseSize, filters: effectiveFilters)
            if effectiveFilters.isEmpty {
                renderedTexture = input
                lease = nil
            } else {
                let result = try makeIO(element: input, filters: effectiveFilters)
                    .configured(for: profile)
                    .renderManagedTexture()
                renderedTexture = result.texture
                lease = result.lease
            }
        } else {
            let input = try source.makeTexture()
            let size_ = source.resolvedSizeHint ?? C7Size(texture: input)
            let effectiveFilters = effectiveFilters(for: size_)
            resolvedSize = resolvedOutputSize(for: size_, filters: effectiveFilters)
            let result = try makeIO(element: input, filters: effectiveFilters)
                .configured(for: profile)
                .renderManagedTexture()
            renderedTexture = result.texture
            lease = result.lease
        }
        return try renderFrame(
            token: token,
            source: source,
            renderedTexture: renderedTexture,
            resolvedSize: resolvedSize,
            filterChain: filters,
            lease: lease
        )
    }

    func materializeFrame(
        renderedTexture: MTLTexture,
        lease: TextureLease?,
        token: FrameRenderToken
    ) throws -> RenderedFrame {
        try renderFrame(
            token: token,
            source: source,
            renderedTexture: renderedTexture,
            resolvedSize: C7Size(texture: renderedTexture),
            filterChain: filters,
            lease: lease
        )
    }

    public func transmitFrame(complete: @escaping @Sendable (Result<RenderedFrame, HarbethError>) -> Void) {
        transmitFrame(token: makeToken(), complete: complete)
    }

    public func transmitFrame(token: FrameRenderToken, complete: @escaping @Sendable (Result<RenderedFrame, HarbethError>) -> Void) {
        if transitionRecipe != nil || recipe != nil {
            do {
                complete(.success(try renderFrame(token: token)))
            } catch {
                complete(.failure(HarbethError.toHarbethError(error)))
            }
            return
        }
        do {
            let input = try source.makeTexture()
            let size_ = source.resolvedSizeHint ?? C7Size(texture: input)
            let effectiveFilters = effectiveFilters(for: size_)
            let resolvedSize = resolvedOutputSize(for: size_, filters: effectiveFilters)
            guard effectiveFilters.isEmpty == false else {
                complete(
                    .success(
                        RenderedFrame(
                            texture: input,
                            colorSpace: resolvedFrameColorSpace(source: source, filterChain: filters),
                            outputColorSpaceContract: resolvedFrameColorSpaceContract(source: source, filterChain: filters),
                            outputToneMappingPolicy: outputToneMappingPolicy ?? .preserveInput,
                            sourceDescriptor: source.descriptor,
                            derivative: outputDerivative,
                            resolvedOutputSize: resolvedSize,
                            renderIntent: renderIntent,
                            sourceTier: source.sourceTier,
                            alphaType: source.alphaType,
                            cachePolicy: outputCachePolicy,
                            semantic: outputSemantic,
                            orientation: source.orientation,
                            profile: profile,
                            token: token,
                            metadata: renderedMetadata(filterChain: filters),
                            lease: nil
                        )
                    )
                )
                return
            }
            makeIO(element: input, filters: effectiveFilters).configured(for: profile).transmitManagedTexture {
                result in
                switch result {
                case .success(let output):
                    complete(
                        .success(
                            RenderedFrame(
                                texture: output.texture,
                                colorSpace: resolvedFrameColorSpace(source: source, filterChain: filters),
                                outputColorSpaceContract: resolvedFrameColorSpaceContract(source: source, filterChain: filters),
                                outputToneMappingPolicy: outputToneMappingPolicy ?? .preserveInput,
                                sourceDescriptor: source.descriptor,
                                derivative: outputDerivative,
                                resolvedOutputSize: resolvedSize,
                                renderIntent: renderIntent,
                                sourceTier: source.sourceTier,
                                alphaType: source.alphaType,
                                cachePolicy: outputCachePolicy,
                                semantic: outputSemantic,
                                orientation: source.orientation,
                                profile: profile,
                                token: token,
                                metadata: renderedMetadata(filterChain: filters),
                                lease: output.lease
                            )
                        )
                    )
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            }
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    private func effectiveFilters(for inputSize: C7Size) -> [C7FilterProtocol] {
        let baseOutputSize = filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        let targetOutputSize = outputDerivative.resolvedOutputSize(for: baseOutputSize)
        let resolvedFilters: [C7FilterProtocol]
        if targetOutputSize == baseOutputSize {
            resolvedFilters = filters
        } else {
            resolvedFilters = filters + [
                C7Resize(width: Float(targetOutputSize.width), height: Float(targetOutputSize.height))
            ]
        }
        return SamplerExecutionAdapter.adapt(
            filters: resolvedFilters,
            samplerDescriptor: samplerDescriptor
        )
    }

    private func resolvedOutputSize(for inputSize: C7Size, filters: [C7FilterProtocol]) -> C7Size {
        filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
    }

    private func renderedMetadata(filterChain: [C7FilterProtocol]) -> [String: String] {
        var value = metadata
        if filterChain.isEmpty == false || value["filterChainFingerprint"] == nil {
            value["filterChainFingerprint"] = filterChain.chainRecipe.fingerprint
        }
        if let outputColorSpace {
            value["outputColorSpace"] = outputColorSpace.name
            value["outputDynamicRange"] = outputColorSpace.dynamicRange.rawValue
        }
        if let outputToneMappingPolicy {
            value["outputToneMappingPolicy"] = outputToneMappingPolicy.rawValue
        }
        return value
    }

    private func resolvedFrameColorSpace(source: ImageSource, filterChain: [C7FilterProtocol]) -> CGColorSpace? {
        let inputSize = source.resolvedSizeHint
        let explicitOutput = outputColorSpace ?? filterChain.reduce(ImageColorSpaceContract.preserveInput) { current, filter in
            let declared = filter.kernelDescriptor(inputSize: inputSize).outputContract.colorSpace
            return declared.preservesInput ? current : declared
        }
        if explicitOutput.preservesInput == false,
           let colorSpace = explicitOutput.cgColorSpace {
            return colorSpace
        }
        if let colorSpace = source.colorSpace {
            return colorSpace
        }
        let sourceDescriptor = source.descriptor
        if let colorSpace = sourceDescriptor.pixelBufferContract?.attachmentColorSpace?.cgColorSpace {
            return colorSpace
        }
        if let colorSpace = sourceDescriptor.sampleBufferContract?.pixelBufferContract?.attachmentColorSpace?.cgColorSpace {
            return colorSpace
        }
        return nil
    }

    private func resolvedFrameColorSpaceContract(source: ImageSource, filterChain: [C7FilterProtocol]) -> ImageColorSpaceContract {
        let inputSize = source.resolvedSizeHint
        let resolvedOutput = outputColorSpace ?? filterChain.reduce(ImageColorSpaceContract.preserveInput) { current, filter in
            let declared = filter.kernelDescriptor(inputSize: inputSize).outputContract.colorSpace
            return declared.preservesInput ? current : declared
        }
        if resolvedOutput.preservesInput == false {
            return resolvedOutput
        }
        if let colorSpace = source.colorSpace {
            return ImageColorSpaceContract(colorSpace: colorSpace)
        }
        let sourceDescriptor = source.descriptor
        if let colorSpace = sourceDescriptor.pixelBufferContract?.attachmentColorSpace {
            return colorSpace
        }
        if let colorSpace = sourceDescriptor.sampleBufferContract?.pixelBufferContract?.attachmentColorSpace {
            return colorSpace
        }
        return .preserveInput
    }

    private func renderFrame(token: FrameRenderToken,
                             source: ImageSource,
                             renderedTexture: MTLTexture,
                             resolvedSize: C7Size,
                             filterChain: [C7FilterProtocol],
                             lease: TextureLease? = nil) throws -> RenderedFrame {
        let previewHostPayload = makePreviewHostPayload(
            source: source,
            renderedTexture: renderedTexture,
            filterChain: filterChain
        )
        return RenderedFrame(
            texture: renderedTexture,
            colorSpace: resolvedFrameColorSpace(source: source, filterChain: filterChain),
            outputColorSpaceContract: resolvedFrameColorSpaceContract(source: source, filterChain: filterChain),
            outputToneMappingPolicy: outputToneMappingPolicy ?? .preserveInput,
            sourceDescriptor: source.descriptor,
            derivative: outputDerivative,
            resolvedOutputSize: resolvedSize,
            renderIntent: renderIntent,
            sourceTier: source.sourceTier,
            alphaType: source.alphaType,
            cachePolicy: outputCachePolicy,
            semantic: outputSemantic,
            orientation: source.orientation,
            profile: profile,
            token: token,
            metadata: renderedMetadata(filterChain: filterChain),
            lease: lease,
            previewHostPayload: previewHostPayload
        )
    }

    private func renderTexture(input: MTLTexture, filters: [C7FilterProtocol], profile: RenderProfile) throws -> MTLTexture {
        guard filters.isEmpty == false else { return input }
        return try makeIO(
            element: input,
            filters: SamplerExecutionAdapter.adapt(filters: filters, samplerDescriptor: samplerDescriptor)
        )
        .configured(for: profile)
        .output()
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture,  derivative: ImageDerivativeSpec, profile: RenderProfile) throws -> MTLTexture {
        let targetSize = derivative.resolvedOutputSize(for: C7Size(texture: texture))
        guard targetSize.width != texture.width || targetSize.height != texture.height else {
            return texture
        }
        return try makeIO(
            element: texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
        )
        .configured(for: profile)
        .output()
    }

    private func makeIO(element: MTLTexture, filters: [C7FilterProtocol]) -> HarbethIO<MTLTexture> {
        HarbethIO(element: element, filters: filters, identifier: identifier)
    }

    private func makeIO(element: MTLTexture, filter: C7FilterProtocol) -> HarbethIO<MTLTexture> {
        HarbethIO(element: element, filter: filter, identifier: identifier)
    }

    private func compiledRecipeExecution(_ recipe: EditRecipe, mode: EditRecipeMode) throws -> CompiledRecipeExecution {
        let compiled = try recipe.compileExecution(
            source: source,
            mode: mode,
            extraFilters: filters,
            derivative: outputDerivative
        )
        return try CompiledRecipeExecution(
            compiled: compiled,
            renderTexture: renderTexture(input:filters:profile:),
            resizeTextureIfNeeded: resizeTextureIfNeeded(_:derivative:profile:)
        )
    }

    private func compiledTransitionExecution(_ recipe: TransitionRecipe) throws -> CompiledTransitionExecution {
        try CompiledTransitionExecution(
            source: recipe.from,
            recipe: recipe,
            extraFilters: filters,
            profile: profile,
            outputDerivative: outputDerivative,
            renderTexture: renderTexture(input:filters:profile:),
            resizeTextureIfNeeded: resizeTextureIfNeeded(_:derivative:profile:)
        )
    }

    private func makePreviewHostPayload(source: ImageSource, renderedTexture: MTLTexture, filterChain: [C7FilterProtocol]) -> RenderedFramePreviewHostPayload? {
        guard case .sampleBuffer(let sampleBuffer) = source else {
            return nil
        }
        let sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let sourceWidth = sourceImageBuffer.map(CVPixelBufferGetWidth)
        let sourceHeight = sourceImageBuffer.map(CVPixelBufferGetHeight)
        let preservesDisplaySemantics = filterChain.isEmpty && sourceWidth == renderedTexture.width && sourceHeight == renderedTexture.height
        let referenceSampleBuffer = sampleBuffer.c7.makeLightweightReferenceSampleBuffer()
        if preservesDisplaySemantics {
            return RenderedFramePreviewHostPayload(passthroughSampleBuffer: referenceSampleBuffer)
        }
        return RenderedFramePreviewHostPayload(sampleBufferFactory: {
            try Self.makeRematerializedSampleBuffer(
                texture: renderedTexture,
                referenceSampleBuffer: referenceSampleBuffer ?? sampleBuffer
            )
        })
    }

    private static func makeRematerializedSampleBuffer(texture: MTLTexture, referenceSampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer? {
        let referencePixelBuffer = CMSampleBufferGetImageBuffer(referenceSampleBuffer)
        let referenceFormatType = referencePixelBuffer.map(CVPixelBufferGetPixelFormatType)
        let resolvedFormatType: OSType
        if let referencePixelBuffer,
           referencePixelBuffer.c7.contract.planar == false,
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
}

private struct CompiledRecipeExecution {
    let source: ImageSource
    let profile: RenderProfile
    let diagnosticFilters: [C7FilterProtocol]
    let resolvedOutputSize: C7Size
    let renderTextureClosure: () throws -> MTLTexture

    init(compiled: CompiledEditRecipeExecution,
         renderTexture: @escaping (MTLTexture, [C7FilterProtocol], RenderProfile) throws -> MTLTexture,
         resizeTextureIfNeeded: @escaping (MTLTexture, ImageDerivativeSpec, RenderProfile) throws -> MTLTexture) throws {
        self.source = compiled.source
        self.profile = compiled.profile
        self.diagnosticFilters = compiled.diagnosticFilters
        self.resolvedOutputSize = compiled.resolvedOutputSize
        self.renderTextureClosure = {
            var currentTexture = try renderTexture(compiled.inputTexture, compiled.baseFilters, compiled.profile)
            for localEffect in compiled.localEffects {
                let filteredTexture = try renderTexture(currentTexture, localEffect.filters, compiled.profile)
                let effectTexture: MTLTexture
                if let blendType = localEffect.foregroundBlendType {
                    effectTexture = try renderTexture(
                        currentTexture,
                        [C7Blend(with: blendType, blendTexture: filteredTexture, intensity: localEffect.foregroundBlendOpacity)],
                        compiled.profile
                    )
                } else {
                    effectTexture = filteredTexture
                }
                currentTexture = try renderTexture(
                    currentTexture,
                    [MaskRegionBlend(effectTexture: effectTexture, mask: localEffect.mask)],
                    compiled.profile
                )
            }
            return try resizeTextureIfNeeded(currentTexture, compiled.derivative, compiled.profile)
        }
    }

    func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }
}

private struct CompiledTransitionExecution {
    let source: ImageSource
    let profile: RenderProfile
    let diagnosticFilters: [C7FilterProtocol]
    let resolvedOutputSize: C7Size
    let renderTextureClosure: () throws -> MTLTexture

    init(source: ImageSource,
         recipe: TransitionRecipe,
         extraFilters: [C7FilterProtocol],
         profile: RenderProfile,
         outputDerivative: ImageDerivativeSpec,
         renderTexture: @escaping (MTLTexture, [C7FilterProtocol], RenderProfile) throws -> MTLTexture,
         resizeTextureIfNeeded: @escaping (MTLTexture, ImageDerivativeSpec, RenderProfile) throws -> MTLTexture) throws {
        let input = try source.makeTexture()
        let inputSize = C7Size(texture: input)
        var filters = [try recipe.makeFilter()] + extraFilters
        let baseOutputSize = filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        let derivativeOutputSize = outputDerivative.resolvedOutputSize(for: baseOutputSize)
        if derivativeOutputSize != baseOutputSize {
            filters.append(C7Resize(width: Float(derivativeOutputSize.width), height: Float(derivativeOutputSize.height)))
        }
        self.source = source
        self.profile = profile
        self.diagnosticFilters = filters
        self.resolvedOutputSize = filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        self.renderTextureClosure = {
            let rendered = try renderTexture(input, [try recipe.makeFilter()] + extraFilters, profile)
            return try resizeTextureIfNeeded(rendered, outputDerivative, profile)
        }
    }

    func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }
}

enum FrameGeneration {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var current: UInt64 = 0

    static func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        current &+= 1
        return current
    }
}

private extension FrameOrientation {
    var imageOrientation: C7ImageOrientation {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        case .unknown:
            return .up
        }
    }

}
