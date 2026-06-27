//
//  LayerCompositeRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreGraphics
import Metal

public enum LayerBlendMode: Int, Sendable, Codable, Equatable, Hashable {
    case normal = 0
    case sourceOver = 1
    case add = 2
    case multiply = 3
    case screen = 4
    case overlay = 5
    case darken = 6
    case lighten = 7
    case difference = 8
    case subtract = 9
    case colorDodge = 10
    case colorBurn = 11
    case softLight = 12
    case hardLight = 13
    case exclusion = 14
}

public enum LayerLayoutUnit: String, Sendable, Codable, Equatable, Hashable {
    case normalized
    case pixel
}

public enum LayerCornerCurve: String, Sendable, Codable, Equatable, Hashable {
    case circular
    case continuous
}

public struct LayerFlipOptions: Sendable, Codable, Equatable, Hashable {
    public var horizontal: Bool
    public var vertical: Bool

    public init(horizontal: Bool = false, vertical: Bool = false) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public var fingerprint: String {
        "h=\(horizontal ? 1 : 0)|v=\(vertical ? 1 : 0)"
    }
}

public struct LayerProgrammableBlend: Sendable, Codable, Equatable, Hashable {
    public let functionName: String
    public let intensity: Float
    public let capability: C7MetalCapability
    public let librarySource: KernelLibrarySource
    public let functionConstants: [KernelFunctionConstantDescriptor]

    public init(functionName: String,
                intensity: Float = 1.0,
                capability: C7MetalCapability = .customAdvancedEncoder,
                librarySource: KernelLibrarySource = .automatic,
                functionConstants: [KernelFunctionConstantDescriptor] = []) {
        self.functionName = functionName
        self.intensity = min(max(intensity, 0), 1)
        self.capability = capability
        self.librarySource = librarySource
        self.functionConstants = functionConstants
    }

    public var fingerprint: String {
        let constantsFingerprint = functionConstants.map(\.fingerprint).joined(separator: "||")
        let identity = KernelFunctionIdentity(
            kind: .advancedMetal,
            primaryName: functionName,
            librarySource: librarySource,
            functionConstants: functionConstants
        )
        return [
            "function=\(functionName)",
            "intensity=\(String(format: "%.4f", intensity))",
            "capability=\(capability.rawValue)",
            identity.librarySource.fingerprint,
            "constants=\(constantsFingerprint.isEmpty ? "none" : constantsFingerprint)"
        ].joined(separator: "|")
    }
}

public struct ImageLayer {
    public var content: ImageSource
    public var filters: [C7FilterProtocol]
    public var normalizedFrame: CGRect
    public var contentRegion: CGRect
    public var layoutUnit: LayerLayoutUnit
    public var opacity: Float
    public var blendMode: LayerBlendMode
    public var transform: ImageTransformRecipe
    public var flipOptions: LayerFlipOptions
    public var rotation: Float
    public var tintColor: SIMD4<Float>?
    public var mask: MaskDescriptor?
    public var maskRecipe: MaskCompositeRecipe?
    public var maskGradientRecipe: MaskGradientRecipe?
    public var maskShapeRecipe: MaskShapeRecipe?
    public var compositingMask: MaskDescriptor?
    public var compositingMaskRecipe: MaskCompositeRecipe?
    public var compositingMaskGradientRecipe: MaskGradientRecipe?
    public var compositingMaskShapeRecipe: MaskShapeRecipe?
    public var programmableBlend: LayerProgrammableBlend?
    public var cornerRadius: Float
    public var cornerCurve: LayerCornerCurve
    public var rasterSampleCount: Int

    public init(content: ImageSource,
                filters: [C7FilterProtocol] = [],
                normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                contentRegion: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                layoutUnit: LayerLayoutUnit = .normalized,
                opacity: Float = 1,
                blendMode: LayerBlendMode = .sourceOver,
                transform: ImageTransformRecipe = ImageTransformRecipe(),
                flipOptions: LayerFlipOptions = LayerFlipOptions(),
                rotation: Float = 0,
                tintColor: SIMD4<Float>? = nil,
                mask: MaskDescriptor? = nil,
                maskRecipe: MaskCompositeRecipe? = nil,
                maskGradientRecipe: MaskGradientRecipe? = nil,
                maskShapeRecipe: MaskShapeRecipe? = nil,
                compositingMask: MaskDescriptor? = nil,
                compositingMaskRecipe: MaskCompositeRecipe? = nil,
                compositingMaskGradientRecipe: MaskGradientRecipe? = nil,
                compositingMaskShapeRecipe: MaskShapeRecipe? = nil,
                programmableBlend: LayerProgrammableBlend? = nil,
                cornerRadius: Float = 0,
                cornerCurve: LayerCornerCurve = .circular,
                rasterSampleCount: Int = 1) {
        self.content = content
        self.filters = filters
        self.normalizedFrame = ImageLayer.clampedNormalizedFrame(normalizedFrame)
        self.contentRegion = ImageLayer.clampedNormalizedFrame(contentRegion)
        self.layoutUnit = layoutUnit
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.transform = transform
        self.flipOptions = flipOptions
        self.rotation = rotation
        self.tintColor = tintColor
        self.mask = mask
        self.maskRecipe = maskRecipe
        self.maskGradientRecipe = maskGradientRecipe
        self.maskShapeRecipe = maskShapeRecipe
        self.compositingMask = compositingMask
        self.compositingMaskRecipe = compositingMaskRecipe
        self.compositingMaskGradientRecipe = compositingMaskGradientRecipe
        self.compositingMaskShapeRecipe = compositingMaskShapeRecipe
        self.programmableBlend = programmableBlend
        self.cornerRadius = max(cornerRadius, 0)
        self.cornerCurve = cornerCurve
        self.rasterSampleCount = max(rasterSampleCount, 1)
    }

    public var hasMask: Bool {
        mask != nil
        || maskRecipe != nil
        || maskGradientRecipe != nil
        || maskShapeRecipe != nil
        || compositingMask != nil
        || compositingMaskRecipe != nil
        || compositingMaskGradientRecipe != nil
        || compositingMaskShapeRecipe != nil
    }

    public var fingerprint: String {
        let frameFingerprint = Self.rectFingerprint(label: "frame", rect: normalizedFrame)
        let contentRegionFingerprint = Self.rectFingerprint(label: "contentRegion", rect: contentRegion)
        let tintFingerprint = tintColor.map { "\($0.x),\($0.y),\($0.z),\($0.w)" } ?? "none"
        let filterFingerprint = filters.isEmpty ? "none" : filters.chainRecipe.fingerprint
        let maskFingerprint: String
        if let maskShapeRecipe {
            maskFingerprint = "shape{\(maskShapeRecipe.fingerprint)}"
        } else if let maskGradientRecipe {
            maskFingerprint = "gradient{\(maskGradientRecipe.fingerprint)}"
        } else if let maskRecipe {
            maskFingerprint = "recipe{\(maskRecipe.fingerprint)}"
        } else if let mask {
            maskFingerprint = Self.maskFingerprint(mask)
        } else {
            maskFingerprint = "none"
        }

        let compositingMaskFingerprint: String
        if let compositingMaskShapeRecipe {
            compositingMaskFingerprint = "shape{\(compositingMaskShapeRecipe.fingerprint)}"
        } else if let compositingMaskGradientRecipe {
            compositingMaskFingerprint = "gradient{\(compositingMaskGradientRecipe.fingerprint)}"
        } else if let compositingMaskRecipe {
            compositingMaskFingerprint = "recipe{\(compositingMaskRecipe.fingerprint)}"
        } else if let compositingMask {
            compositingMaskFingerprint = Self.maskFingerprint(compositingMask)
        } else {
            compositingMaskFingerprint = "none"
        }

        return [
            frameFingerprint,
            contentRegionFingerprint,
            "layout=\(layoutUnit.rawValue)",
            "opacity=\(String(format: "%.4f", opacity))",
            "blend=\(blendMode.rawValue)",
            "transform=\(transform.fingerprint)",
            "flip=\(flipOptions.fingerprint)",
            "rotation=\(String(format: "%.4f", rotation))",
            "tint=\(tintFingerprint)",
            "filters=\(filterFingerprint)",
            "mask=\(maskFingerprint)",
            "compositingMask=\(compositingMaskFingerprint)",
            "programmableBlend=\(programmableBlend?.fingerprint ?? "none")",
            "corner=\(String(format: "%.4f", cornerRadius))",
            "cornerCurve=\(cornerCurve.rawValue)",
            "samples=\(rasterSampleCount)"
        ].joined(separator: "|")
    }

    private static func rectFingerprint(label: String, rect: CGRect) -> String {
        [
            "\(label)=\(stableFloatDescription(Double(rect.origin.x))),\(stableFloatDescription(Double(rect.origin.y))),\(stableFloatDescription(Double(rect.width))),\(stableFloatDescription(Double(rect.height)))"
        ].joined(separator: "|")
    }

    private static func stableFloatDescription(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    func resolvedMaskDescriptor() throws -> MaskDescriptor? {
        if let maskShapeRecipe {
            return try maskShapeRecipe.makeMaskDescriptor()
        }
        if let maskGradientRecipe {
            return try maskGradientRecipe.makeMaskDescriptor()
        }
        if let maskRecipe {
            return try maskRecipe.makeMaskDescriptor()
        }
        return mask
    }

    func resolvedCompositingMaskDescriptor() throws -> MaskDescriptor? {
        if let compositingMaskShapeRecipe {
            return try compositingMaskShapeRecipe.makeMaskDescriptor()
        }
        if let compositingMaskGradientRecipe {
            return try compositingMaskGradientRecipe.makeMaskDescriptor()
        }
        if let compositingMaskRecipe {
            return try compositingMaskRecipe.makeMaskDescriptor()
        }
        return compositingMask
    }

    var maskGraphDescriptor: MaskGraphDescriptor? {
        maskShapeRecipe?.graphDescriptor
        ?? maskGradientRecipe?.graphDescriptor
        ?? maskRecipe?.graphDescriptor
        ?? mask?.graphDescriptor
    }

    var compositingMaskGraphDescriptor: MaskGraphDescriptor? {
        compositingMaskShapeRecipe?.graphDescriptor
        ?? compositingMaskGradientRecipe?.graphDescriptor
        ?? compositingMaskRecipe?.graphDescriptor
        ?? compositingMask?.graphDescriptor
    }

    private static func clampedNormalizedFrame(_ rect: CGRect) -> CGRect {
        let standardized = rect.standardized
        let x = min(max(standardized.origin.x, 0), 1)
        let y = min(max(standardized.origin.y, 0), 1)
        let width = min(max(standardized.width, 0), 1 - x)
        let height = min(max(standardized.height, 0), 1 - y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func maskFingerprint(_ descriptor: MaskDescriptor) -> String {
        [
            "component=\(descriptor.component.rawValue)",
            "blend=\(descriptor.blendMode.rawValue)",
            "invert=\(descriptor.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", descriptor.opacity))",
            "feather=\(descriptor.featherPolicy.amount)"
        ].joined(separator: ",")
    }
}

public struct LayerCompositeRecipe {
    public var background: ImageSource
    public var layers: [ImageLayer]
    public var profile: RenderProfile
    public var derivative: ImageDerivativeSpec
    public var outputContract: RenderOutputContract

    public init(background: ImageSource,
                layers: [ImageLayer],
                profile: RenderProfile = .stablePreview,
                derivative: ImageDerivativeSpec? = nil,
                outputContract: RenderOutputContract = .preserveInput) {
        self.background = background
        self.layers = layers
        self.profile = profile
        self.derivative = derivative ?? profile.defaultDerivativeSpec
        self.outputContract = outputContract
    }

    public var layerCount: Int {
        layers.count
    }

    public var fingerprint: String {
        [
            "layers=\(layers.map(\.fingerprint).joined(separator: "||"))",
            "profile=\(profile)",
            "derivative=\(derivative.name)",
            outputContract.fingerprint
        ].joined(separator: "|")
    }

    public func makeNode() -> ImageNode {
        .layerComposite(self)
    }

    func makeRenderRecipe(profile: RenderProfile? = nil,
                          derivative: ImageDerivativeSpec? = nil,
                          samplerDescriptor: ImageSamplerDescriptor = .default) throws -> RenderRecipe {
        let plan = try makeRenderPlan(
            profile: profile,
            derivative: derivative,
            samplerDescriptor: samplerDescriptor
        )
        let filters = plan.diagnostics.nodes
            .filter { $0.name != "DerivativeResize" }
            .map { diagnostic in
                FilterRecipeDescriptor(
                    stableTypeID: diagnostic.name,
                    modifier: diagnostic.kind.rawValue,
                    parameterValues: diagnostic.parameterSummary
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" },
                    otherInputTextureCount: 0,
                    pipelineFilterFingerprints: [],
                    finalFilterFingerprint: nil
                )
            }
        return RenderRecipe(
            renderProfile: String(describing: plan.profile),
            renderIntent: plan.diagnostics.derivative.renderIntent,
            source: background.descriptor,
            outputDerivative: plan.diagnostics.derivative,
            outputCachePolicy: .transient,
            outputSemantic: plan.diagnostics.derivative.semantic,
            alphaType: background.alphaType,
            orientation: background.orientation,
            filters: filters,
            localEffects: nil,
            layerMasks: layerMaskDescriptors
        )
    }

    func makeRenderRequest(profile: RenderProfile? = nil,
                           derivative: ImageDerivativeSpec? = nil,
                           samplerDescriptor: ImageSamplerDescriptor = .default) throws -> RenderRequest {
        let effectiveProfile = profile ?? self.profile
        let effectiveDerivative = derivative ?? self.derivative
        let node = makeNode().withSamplerDescriptor(samplerDescriptor)
        let diagnostics = try node.makeDiagnostics(profile: effectiveProfile, derivative: effectiveDerivative)
        let recipeDescriptor = try makeRenderRecipe(
            profile: effectiveProfile,
            derivative: effectiveDerivative,
            samplerDescriptor: samplerDescriptor
        )
        let attachmentPolicies = try node.makeAttachmentDebugPolicies(profile: effectiveProfile, derivative: effectiveDerivative)
        return RenderRequest(
            compilationSource: .layerComposite,
            profile: effectiveProfile,
            derivative: effectiveDerivative,
            source: background.descriptor,
            outputCachePolicy: .transient,
            diagnostics: diagnostics,
            renderRecipe: recipeDescriptor,
            renderTexture: {
                try makeTexture(
                    profile: effectiveProfile,
                    derivative: effectiveDerivative,
                    samplerDescriptor: samplerDescriptor
                )
            },
            renderFrame: { metadata in
                try node.makeFrame(profile: effectiveProfile, derivative: effectiveDerivative, metadata: metadata)
            },
            renderAnalysisBundle: { channel, bins, histogramHeight, region, preferredMethod in
                let frame = try node.makeFrame(profile: effectiveProfile, derivative: effectiveDerivative)
                let histogramAttachment = frame.renderHistogramAttachment(
                    channel: channel,
                    bins: bins,
                    height: histogramHeight,
                    region: region,
                    preferredMethod: preferredMethod
                )
                let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
                    channel: channel,
                    bins: bins,
                    region: region,
                    preferredMethod: preferredMethod
                )
                let statistics = frame.makeStatistics(region: region)
                let colorProbe = frame.makeColorProbe(region: region)
                return RenderedAnalysisBundle(
                    frame: frame,
                    histogram: histogram,
                    statistics: statistics,
                    colorProbe: colorProbe,
                    histogramAttachment: histogramAttachment,
                    analysisScopeFingerprint: TextureAnalysisScope(region: region).fingerprint,
                    attachmentDebugPolicies: attachmentPolicies
                )
            },
            renderAnalysisScopeBundle: { channel, bins, histogramHeight, scope, preferredMethod in
                let frame = try node.makeFrame(profile: effectiveProfile, derivative: effectiveDerivative)
                let histogramAttachment = frame.renderHistogramAttachment(
                    channel: channel,
                    bins: bins,
                    height: histogramHeight,
                    scope: scope,
                    preferredMethod: preferredMethod
                )
                let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
                    channel: channel,
                    bins: bins,
                    scope: scope,
                    preferredMethod: preferredMethod
                )
                let statistics = frame.makeStatistics(scope: scope)
                let colorProbe = frame.makeColorProbe(scope: scope)
                return RenderedAnalysisBundle(
                    frame: frame,
                    histogram: histogram,
                    statistics: statistics,
                    colorProbe: colorProbe,
                    histogramAttachment: histogramAttachment,
                    analysisScopeFingerprint: scope.fingerprint,
                    attachmentDebugPolicies: attachmentPolicies
                )
            },
            renderAttachmentSet: {
                try node.makeAttachmentSet(profile: effectiveProfile)
            },
            renderAttachmentAnalysisBundle: { bins, histogramHeight, region, preferredMethod in
                try node.makeAttachmentAnalysisBundle(
                    profile: effectiveProfile,
                    bins: bins,
                    histogramHeight: histogramHeight,
                    region: region,
                    preferredMethod: preferredMethod
                )
            },
            renderAttachmentAnalysisScopeBundle: { bins, histogramHeight, scope, preferredMethod in
                try node.makeAttachmentAnalysisBundle(
                    profile: effectiveProfile,
                    bins: bins,
                    histogramHeight: histogramHeight,
                    scope: scope,
                    preferredMethod: preferredMethod
                )
            }
        )
    }

    var layerMaskDescriptors: [LayerMaskRecipeDescriptor]? {
        let descriptors = layers.enumerated().compactMap { index, layer -> LayerMaskRecipeDescriptor? in
            let mask = layer.maskGraphDescriptor
            let compositingMask = layer.compositingMaskGraphDescriptor
            guard mask != nil || compositingMask != nil else {
                return nil
            }
            return LayerMaskRecipeDescriptor(
                layerIndex: index,
                mask: mask,
                compositingMask: compositingMask
            )
        }
        return descriptors.isEmpty ? nil : descriptors
    }
}

extension LayerCompositeRecipe {
    func makeRenderPlan(profile: RenderProfile? = nil,
                        derivative: ImageDerivativeSpec? = nil,
                        samplerDescriptor: ImageSamplerDescriptor = .default) throws -> RenderPlan {
        let effectiveProfile = profile ?? self.profile
        let backgroundSize: C7Size
        let placeholderTexture: MTLTexture
        if let size = background.resolvedSizeHint {
            backgroundSize = size
            placeholderTexture = try background.makeTexture()
        } else {
            let backgroundTexture = try background.makeTexture()
            backgroundSize = C7Size(width: backgroundTexture.width, height: backgroundTexture.height)
            placeholderTexture = backgroundTexture
        }
        let layerPreparationFilters = layers.flatMap { layer -> [C7FilterProtocol] in
            var layerTransform = layer.transform
            if layer.rotation.truncatingRemainder(dividingBy: 360) != 0 {
                layerTransform.rotationDegrees += layer.rotation
            }
            if layer.flipOptions.horizontal {
                layerTransform.mirrorsHorizontally.toggle()
            }
            if layer.flipOptions.vertical {
                layerTransform.flipsVertically.toggle()
            }
            return layerTransform.makeFilters(
                inputSize: C7Size(width: placeholderTexture.width, height: placeholderTexture.height)
            ) + layer.filters
        }
        let filters = try layers.flatMap { layer -> [C7FilterProtocol] in
            let resolvedMask = try layer.resolvedMaskDescriptor()
            let resolvedCompositingMask = try layer.resolvedCompositingMaskDescriptor()
            let composite = LayerComposite(
                layerTexture: placeholderTexture,
                mask: resolvedMask,
                compositingMask: resolvedCompositingMask,
                normalizedFrame: layer.normalizedFrame,
                contentRegion: layer.contentRegion,
                opacity: layer.opacity,
                blendMode: layer.programmableBlend == nil ? layer.blendMode : .sourceOver,
                cornerRadius: layer.cornerRadius,
                cornerCurve: layer.cornerCurve,
                tintColor: layer.tintColor
            )
            guard let programmableBlend = layer.programmableBlend else {
                return [composite]
            }
            return [
                composite,
                C7ProgrammableBlend(
                    functionName: programmableBlend.functionName,
                    blendTexture: placeholderTexture,
                    intensity: programmableBlend.intensity,
                    capability: programmableBlend.capability,
                    librarySource: programmableBlend.librarySource,
                    functionConstants: programmableBlend.functionConstants
                )
            ]
        }
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: backgroundSize,
            profile: effectiveProfile,
            derivative: derivative ?? self.derivative,
            compilationSource: .layerComposite,
            outputContract: outputContract,
            samplerDescriptor: samplerDescriptor,
            sourceDescriptor: background.descriptor
        )
        let preparationCoverage = SamplerExecutionAdapter.coverage(
            for: layerPreparationFilters,
            samplerDescriptor: samplerDescriptor
        )
        return plan.withSamplerExecutionCoverage(
            SamplerExecutionAdapter.merge(plan.diagnostics.samplerExecutionCoverage, preparationCoverage)
        )
    }

    func makeTexture(profile: RenderProfile? = nil,
                     derivative: ImageDerivativeSpec? = nil,
                     samplerDescriptor: ImageSamplerDescriptor = .default) throws -> MTLTexture {
        let effectiveProfile = profile ?? self.profile
        // Layer Compose 智能合并（评估结论：暂不 fusion）
        //
        // 评估过把 N 个 layer 折叠为单 compute pass：
        //   * `LayerComposite` 是 `RenderProtocol`（render encoder），
        //     不是 compute kernel。它的 `layerTexture` 是 `otherInputTextures`
        //     之一，必须在 render encoder 当帧绑定，无法用单个 compute pass
        //     "一次性" 串起多张 layer 输入。
        //   * 即便全部强制 compute，`LayerComposite` 当前没有 compute shader
        //     实现，重写成本与正确性风险远大于节省的 dispatch。
        //   * `programmableBlend` 分支额外引入了 "layer canvas + programmable blend"
        //     双 render pass，结构和普通 layer 不一致，单 pass fusion 会跳过它，
        //     反而引入行为分歧。
        //
        // 结论：保留 "每个 layer 一个 render pass + 末尾 output contract" 的现状。
        // 后续若提供 `LayerComposite.compute(otherInputs:)` 入口，可再开启 fusion。
        var current = try background.makeTexture()
        guard layers.isEmpty == false else {
            return try resizeTextureIfNeeded(
                current,
                derivative: derivative ?? self.derivative,
                profile: effectiveProfile
            )
        }

        for layer in layers {
            var layerTexture = try layer.content.makeTexture()
            let resolvedMask = try layer.resolvedMaskDescriptor()
            let resolvedCompositingMask = try layer.resolvedCompositingMaskDescriptor()
            var layerTransform = layer.transform
            if layer.rotation.truncatingRemainder(dividingBy: 360) != 0 {
                layerTransform.rotationDegrees += layer.rotation
            }
            if layer.flipOptions.horizontal {
                layerTransform.mirrorsHorizontally.toggle()
            }
            if layer.flipOptions.vertical {
                layerTransform.flipsVertically.toggle()
            }
            let layerFilters = layerTransform.makeFilters(
                inputSize: C7Size(width: layerTexture.width, height: layerTexture.height)
            ) + layer.filters
            if layerFilters.isEmpty == false {
                layerTexture = try HarbethIO(
                    element: layerTexture,
                    filters: SamplerExecutionAdapter.adapt(
                        filters: layerFilters,
                        samplerDescriptor: samplerDescriptor
                    )
                )
                .configured(for: effectiveProfile)
                .output()
            }
            if let programmableBlend = layer.programmableBlend {
                let preparedLayer = try makeTransparentCanvas(matching: current)
                let layerCanvas = try HarbethIO(
                    element: preparedLayer,
                    filter: LayerComposite(
                        layerTexture: layerTexture,
                        mask: resolvedMask,
                        compositingMask: resolvedCompositingMask,
                        normalizedFrame: layer.normalizedFrame,
                        contentRegion: layer.contentRegion,
                        opacity: layer.opacity,
                        blendMode: .sourceOver,
                        cornerRadius: layer.cornerRadius,
                        cornerCurve: layer.cornerCurve,
                        tintColor: layer.tintColor
                    )
                )
                .configured(for: effectiveProfile)
                .output()
                current = try HarbethIO(
                    element: current,
                    filter: C7ProgrammableBlend(
                        functionName: programmableBlend.functionName,
                        blendTexture: layerCanvas,
                        intensity: programmableBlend.intensity,
                        capability: programmableBlend.capability,
                        librarySource: programmableBlend.librarySource,
                        functionConstants: programmableBlend.functionConstants
                    )
                )
                .configured(for: effectiveProfile)
                .output()
                continue
            }
            current = try HarbethIO(
                element: current,
                filter: LayerComposite(
                    layerTexture: layerTexture,
                    mask: resolvedMask,
                    compositingMask: resolvedCompositingMask,
                    normalizedFrame: layer.normalizedFrame,
                    contentRegion: layer.contentRegion,
                    opacity: layer.opacity,
                    blendMode: layer.blendMode,
                    cornerRadius: layer.cornerRadius,
                    cornerCurve: layer.cornerCurve,
                    tintColor: layer.tintColor
                )
            )
            .configured(for: effectiveProfile)
            .output()
        }
        let contracted = try ImageNode.applyOutputContractIfNeeded(
            outputContract,
            to: current,
            sourceAlphaType: outputContract.inputAlphaExpectation.expectedAlphaType,
            profile: effectiveProfile
        )
        return try resizeTextureIfNeeded(
            contracted,
            derivative: derivative ?? self.derivative,
            profile: effectiveProfile
        )
    }

    func makeDiagnostics(profile: RenderProfile? = nil,
                         derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        try makeRenderPlan(profile: profile, derivative: derivative).diagnostics
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture,
                                       derivative: ImageDerivativeSpec,
                                       profile: RenderProfile) throws -> MTLTexture {
        try ImageNode.applyDerivativeResize(texture, derivative: derivative, profile: profile)
    }

    private func makeTransparentCanvas(matching texture: MTLTexture) throws -> MTLTexture {
        let canvas = try TextureLoader.makeTexture(width: texture.width, height: texture.height, options: [
            .texturePixelFormat: texture.pixelFormat,
            .textureUsage: texture.usage,
            .textureSampleCount: texture.sampleCount
        ], identifier: "LayerCompositeRecipe.TransparentCanvas")

        let bytesPerPixel: Int
        switch texture.pixelFormat {
        case .rgba8Unorm, .bgra8Unorm, .rgba8Snorm, .rgba8Unorm_srgb, .bgra8Unorm_srgb:
            bytesPerPixel = 4
        case .rgba16Float:
            bytesPerPixel = 8
        default:
            throw HarbethError.filterParameterInvalid("Unsupported programmable layer canvas pixel format: \(texture.pixelFormat)")
        }
        let bytesPerRow = texture.width * bytesPerPixel
        let zeroBytes = [UInt8](repeating: 0, count: texture.height * bytesPerRow)
        canvas.replace(
            region: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0,
            withBytes: zeroBytes,
            bytesPerRow: bytesPerRow
        )
        return canvas
    }
}
