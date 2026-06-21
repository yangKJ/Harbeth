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
public enum RenderProfile: Sendable, Equatable {
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

/// texture-first 渲染结果的稳定元数据包装。
public struct RenderedFrame: @unchecked Sendable {
    public let texture: MTLTexture
    public let size: CGSize
    public let pixelFormat: MTLPixelFormat
    public let colorSpace: CGColorSpace?
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

    public init(texture: MTLTexture,
                colorSpace: CGColorSpace? = nil,
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
        self.texture = texture
        self.size = CGSize(width: texture.width, height: texture.height)
        self.pixelFormat = texture.pixelFormat
        self.colorSpace = colorSpace
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
        self.resolvedOutputSize = resolvedOutputSize ?? C7Size(width: texture.width, height: texture.height)
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
    }

    public func isCurrent(comparedTo latestToken: FrameRenderToken) -> Bool {
        guard identifier == latestToken.identifier else { return true }
        return generation >= latestToken.generation
    }

    public var replayBaseContract: ReplayBaseContract {
        derivative.replayBaseContract
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
}

/// 高级渲染流程的终端输出意图。
public enum RenderTarget: Sendable, Equatable {
    case texture
    case frame
    case image
    case pixelBuffer
    case data
}

/// 面向产品级调用方的 texture-first 渲染器，提供稳定帧元数据。
public struct FrameRenderer {
    public let source: ImageSource
    public let filters: [C7FilterProtocol]
    public let recipe: EditRecipe?
    public let recipeMode: EditRecipeMode?
    public let transitionRecipe: TransitionRecipe?
    public var profile: RenderProfile
    public var renderIntent: RenderIntent
    public var identifier: String
    public var metadata: [String: String]
    public var outputCachePolicy: ImageCachePolicy
    public var outputSemantic: ImageSemanticDescriptor
    public var outputDerivative: ImageDerivativeSpec

    public init(source: ImageSource,
                filters: [C7FilterProtocol] = [],
                profile: RenderProfile = .stablePreview,
                renderIntent: RenderIntent? = nil,
                identifier: String = UUID().uuidString,
                metadata: [String: String] = [:],
                outputSemantic: ImageSemanticDescriptor? = nil,
                outputDerivative: ImageDerivativeSpec? = nil,
                outputCachePolicy: ImageCachePolicy? = nil) {
        self.source = source
        self.filters = filters
        self.recipe = nil
        self.recipeMode = nil
        self.transitionRecipe = nil
        self.profile = profile
        self.renderIntent = renderIntent ?? profile.defaultRenderIntent
        self.identifier = identifier
        self.metadata = metadata
        self.outputCachePolicy = outputCachePolicy ?? (filters.isEmpty ? source.cachePolicy : .transient)
        self.outputSemantic = outputSemantic ?? profile.defaultImageSemantic
        self.outputDerivative = outputDerivative ?? profile.defaultDerivativeSpec
    }

    public init(source: ImageSource,
                recipe: EditRecipe,
                mode: EditRecipeMode = .preview,
                filters: [C7FilterProtocol] = [],
                identifier: String = UUID().uuidString,
                metadata: [String: String] = [:],
                derivative: ImageDerivativeSpec? = nil) {
        let contract = recipe.contract(for: mode)
        self.source = source
        self.filters = filters
        self.recipe = recipe
        self.recipeMode = mode
        self.transitionRecipe = nil
        self.profile = contract.profile
        self.renderIntent = contract.renderIntent
        self.identifier = identifier
        self.metadata = metadata
        self.outputCachePolicy = (recipe.geometry.isIdentity && recipe.filters.isEmpty && recipe.localEffects.isEmpty && filters.isEmpty) ? source.cachePolicy : .transient
        self.outputSemantic = contract.derivative.semantic
        self.outputDerivative = derivative ?? contract.derivative
    }

    public init(transitionRecipe: TransitionRecipe,
                filters: [C7FilterProtocol] = [],
                identifier: String = UUID().uuidString,
                metadata: [String: String] = [:]) {
        self.source = transitionRecipe.from
        self.filters = filters
        self.recipe = nil
        self.recipeMode = nil
        self.transitionRecipe = transitionRecipe
        self.profile = transitionRecipe.profile
        self.renderIntent = transitionRecipe.derivative.renderIntent
        self.identifier = identifier
        self.metadata = metadata
        self.outputCachePolicy = .transient
        self.outputSemantic = transitionRecipe.derivative.semantic
        self.outputDerivative = transitionRecipe.derivative
    }

    public func renderTexture() throws -> MTLTexture {
        if let transitionRecipe {
            return try compiledTransitionExecution(transitionRecipe).renderTexture()
        }
        if let recipe, let mode = recipeMode {
            return try compiledRecipeExecution(recipe, mode: mode).renderTexture()
        }
        let input = try source.makeTexture()
        let effectiveFilters = effectiveFilters(for: C7Size(width: input.width, height: input.height))
        guard effectiveFilters.isEmpty == false else { return input }
        return try HarbethIO(element: input, filters: effectiveFilters)
            .configured(for: profile)
            .output()
    }

    public func makeToken() -> FrameRenderToken {
        FrameRenderToken(identifier: identifier, generation: FrameGeneration.next())
    }

    public func renderFrame() throws -> RenderedFrame {
        return try renderFrame(token: makeToken())
    }

    public func renderFrame(token: FrameRenderToken) throws -> RenderedFrame {
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
            let effectiveFilters = effectiveFilters(for: C7Size(width: input.width, height: input.height))
            resolvedSize = resolvedOutputSize(for: C7Size(width: input.width, height: input.height), filters: effectiveFilters)
            if effectiveFilters.isEmpty {
                renderedTexture = input
                lease = nil
            } else {
                let result = try HarbethIO(element: input, filters: effectiveFilters)
                    .configured(for: profile)
                    .renderManagedTexture()
                renderedTexture = result.texture
                lease = result.lease
            }
        } else {
            let input = try source.makeTexture()
            let effectiveFilters = effectiveFilters(for: C7Size(width: input.width, height: input.height))
            resolvedSize = resolvedOutputSize(for: C7Size(width: input.width, height: input.height), filters: effectiveFilters)
            let result = try HarbethIO(element: input, filters: effectiveFilters)
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

    public func transmitFrame(complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        transmitFrame(token: makeToken(), complete: complete)
    }

    public func transmitFrame(token: FrameRenderToken, complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
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
            let effectiveFilters = effectiveFilters(for: C7Size(width: input.width, height: input.height))
            let resolvedSize = resolvedOutputSize(for: C7Size(width: input.width, height: input.height), filters: effectiveFilters)
            guard effectiveFilters.isEmpty == false else {
                complete(.success(RenderedFrame(
                    texture: input,
                    colorSpace: source.colorSpace,
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
                )))
                return
            }
            HarbethIO(element: input, filters: effectiveFilters)
                .configured(for: profile)
                .transmitManagedTexture { result in
                    switch result {
                    case .success(let output):
                        complete(.success(RenderedFrame(
                            texture: output.texture,
                            colorSpace: source.colorSpace,
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
                        )))
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
        guard targetOutputSize != baseOutputSize else {
            return filters
        }
        return filters + [C7Resize(width: Float(targetOutputSize.width), height: Float(targetOutputSize.height))]
    }

    private func resolvedOutputSize(for inputSize: C7Size, filters: [C7FilterProtocol]) -> C7Size {
        filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
    }

    private func renderedMetadata(filterChain: [C7FilterProtocol]) -> [String: String] {
        var value = metadata
        value["filterChainFingerprint"] = filterChain.chainRecipe.fingerprint
        return value
    }

    private func renderFrame(token: FrameRenderToken,
                             source: ImageSource,
                             renderedTexture: MTLTexture,
                             resolvedSize: C7Size,
                             filterChain: [C7FilterProtocol],
                             lease: TextureLease? = nil) throws -> RenderedFrame {
        RenderedFrame(
            texture: renderedTexture,
            colorSpace: source.colorSpace,
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
            lease: lease
        )
    }

    private func renderTexture(input: MTLTexture,
                               filters: [C7FilterProtocol],
                               profile: RenderProfile) throws -> MTLTexture {
        guard filters.isEmpty == false else { return input }
        return try HarbethIO(element: input, filters: filters)
            .configured(for: profile)
            .output()
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture,
                                       derivative: ImageDerivativeSpec,
                                       profile: RenderProfile) throws -> MTLTexture {
        let targetSize = derivative.resolvedOutputSize(for: C7Size(width: texture.width, height: texture.height))
        guard targetSize.width != texture.width || targetSize.height != texture.height else {
            return texture
        }
        return try HarbethIO(
            element: texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
        )
        .configured(for: profile)
        .output()
    }

    private func compiledRecipeExecution(_ recipe: EditRecipe,
                                         mode: EditRecipeMode) throws -> CompiledRecipeExecution {
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
            outputDerivative: outputDerivative,
            renderTexture: renderTexture(input:filters:profile:),
            resizeTextureIfNeeded: resizeTextureIfNeeded(_:derivative:profile:)
        )
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
                let effectTexture = try renderTexture(currentTexture, localEffect.filters, compiled.profile)
                currentTexture = try renderTexture(
                    currentTexture,
                    [C7MaskRegionBlend(effectTexture: effectTexture, mask: localEffect.mask)],
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
         outputDerivative: ImageDerivativeSpec,
         renderTexture: @escaping (MTLTexture, [C7FilterProtocol], RenderProfile) throws -> MTLTexture,
         resizeTextureIfNeeded: @escaping (MTLTexture, ImageDerivativeSpec, RenderProfile) throws -> MTLTexture) throws {
        let input = try source.makeTexture()
        let inputSize = C7Size(width: input.width, height: input.height)
        var filters = [try recipe.makeFilter()] + extraFilters
        let baseOutputSize = filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        let derivativeOutputSize = outputDerivative.resolvedOutputSize(for: baseOutputSize)
        if derivativeOutputSize != baseOutputSize {
            filters.append(C7Resize(width: Float(derivativeOutputSize.width), height: Float(derivativeOutputSize.height)))
        }
        self.source = source
        self.profile = recipe.profile
        self.diagnosticFilters = filters
        self.resolvedOutputSize = filters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        self.renderTextureClosure = {
            let rendered = try renderTexture(input, [try recipe.makeFilter()] + extraFilters, recipe.profile)
            return try resizeTextureIfNeeded(rendered, outputDerivative, recipe.profile)
        }
    }

    func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }
}

enum FrameGeneration {
    private static let lock = NSLock()
    private static var current: UInt64 = 0

    static func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        current &+= 1
        return current
    }
}
