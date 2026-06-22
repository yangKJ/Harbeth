//
//  RenderGraph.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

enum RenderNodeKind: String, Sendable, Codable, Equatable, Hashable {
    case compute
    case render
    case blit
    case mps
    case advancedMetal
    case combination
    case boundary
}

struct RenderNode {
    let kind: RenderNodeKind
    let filter: C7FilterProtocol?
    let boundary: (RenderBoundaryAdapter)?
    let outputSize: C7Size?
    let breaksFusion: Bool

    init(kind: RenderNodeKind,
         filter: C7FilterProtocol? = nil,
         boundary: (RenderBoundaryAdapter)? = nil,
         outputSize: C7Size? = nil,
         breaksFusion: Bool = false) {
        self.kind = kind
        self.filter = filter
        self.boundary = boundary
        self.outputSize = outputSize
        self.breaksFusion = breaksFusion
    }
}

struct RenderGraph {
    let nodes: [RenderNode]

    init(nodes: [RenderNode]) {
        self.nodes = nodes
    }
}

enum RenderStageKind: String, Sendable, Codable, Equatable, Hashable {
    case compute
    case render
    case blit
    case boundary
}

enum RenderStageBoundaryReason: String, Sendable, Codable, Equatable, Hashable {
    case externalBoundary
    case fusionBoundary
    case readbackReady
}

public enum RenderCompilationSource: String, Sendable, Codable, Equatable, Hashable {
    case filtersPrimitive
    case editRecipe
    case transition
    case nodeGraph
    case layerComposite
}

public enum RenderTextureLifecycleAction: String, Sendable, Codable, Equatable, Hashable {
    case allocatePersistentOutput
    case allocateTransient
    case reuseTransient
    case preserveForReadback
}

public enum RenderTextureReservationReason: String, Sendable, Codable, Equatable, Hashable {
    case transientReuse
    case persistentOutput
    case readbackOutput
}

public struct RenderTextureReservation: Sendable, Codable, Equatable, Hashable {
    public let stageIndices: [Int]
    public let size: C7Size
    public let pixelFormat: PixelFormatContract
    public let reason: RenderTextureReservationReason
    public let count: Int

    public init(stageIndices: [Int],
                size: C7Size,
                pixelFormat: PixelFormatContract,
                reason: RenderTextureReservationReason,
                count: Int = 1) {
        self.stageIndices = stageIndices
        self.size = size
        self.pixelFormat = pixelFormat
        self.reason = reason
        self.count = count
    }
}

public struct RenderTextureLifecycleDecision: Sendable, Codable, Equatable, Hashable {
    public let stageIndex: Int
    public let action: RenderTextureLifecycleAction
    public let size: C7Size
    public let reason: String

    public init(stageIndex: Int,
                action: RenderTextureLifecycleAction,
                size: C7Size,
                reason: String) {
        self.stageIndex = stageIndex
        self.action = action
        self.size = size
        self.reason = reason
    }
}

public struct RenderOptimizationPlan: Sendable, Codable, Equatable, Hashable {
    public let intermediateTextureCount: Int
    public let reusableTextureCount: Int
    public let persistentOutputCount: Int
    public let mergedStageCount: Int
    public let fusionEligibleNodeCount: Int
    public let transientStageCount: Int
    public let renderStageCount: Int
    public let estimatedTransientByteCount: Int
    public let estimatedPersistentByteCount: Int
    public let readbackBoundaryCount: Int
    public let formatConversionCount: Int
    public let destinationTextureCreationCount: Int
    public let allocationStrategy: TextureAllocationStrategy
    public let requestedAllocationStrategy: TextureAllocationStrategy?
    public let allocationFallbackReason: String?
    public let textureRequestCount: Int
    public let textureReuseHitCount: Int
    public let heapBackedAllocationCount: Int
    public let prewarmReservations: [RenderTextureReservation]
    public let lifecycleDecisions: [RenderTextureLifecycleDecision]
    public let decisions: [String]
    public let allocatorDecisions: [String]

    public init(intermediateTextureCount: Int,
                reusableTextureCount: Int,
                persistentOutputCount: Int,
                mergedStageCount: Int,
                fusionEligibleNodeCount: Int,
                transientStageCount: Int,
                renderStageCount: Int,
                estimatedTransientByteCount: Int,
                estimatedPersistentByteCount: Int,
                readbackBoundaryCount: Int,
                formatConversionCount: Int,
                destinationTextureCreationCount: Int,
                allocationStrategy: TextureAllocationStrategy,
                requestedAllocationStrategy: TextureAllocationStrategy? = nil,
                allocationFallbackReason: String? = nil,
                textureRequestCount: Int,
                textureReuseHitCount: Int,
                heapBackedAllocationCount: Int,
                prewarmReservations: [RenderTextureReservation],
                lifecycleDecisions: [RenderTextureLifecycleDecision],
                decisions: [String],
                allocatorDecisions: [String]) {
        self.intermediateTextureCount = intermediateTextureCount
        self.reusableTextureCount = reusableTextureCount
        self.persistentOutputCount = persistentOutputCount
        self.mergedStageCount = mergedStageCount
        self.fusionEligibleNodeCount = fusionEligibleNodeCount
        self.transientStageCount = transientStageCount
        self.renderStageCount = renderStageCount
        self.estimatedTransientByteCount = estimatedTransientByteCount
        self.estimatedPersistentByteCount = estimatedPersistentByteCount
        self.readbackBoundaryCount = readbackBoundaryCount
        self.formatConversionCount = formatConversionCount
        self.destinationTextureCreationCount = destinationTextureCreationCount
        self.allocationStrategy = allocationStrategy
        self.requestedAllocationStrategy = requestedAllocationStrategy
        self.allocationFallbackReason = allocationFallbackReason
        self.textureRequestCount = textureRequestCount
        self.textureReuseHitCount = textureReuseHitCount
        self.heapBackedAllocationCount = heapBackedAllocationCount
        self.prewarmReservations = prewarmReservations
        self.lifecycleDecisions = lifecycleDecisions
        self.decisions = decisions
        self.allocatorDecisions = allocatorDecisions
    }

    public var textureReuseHitRatio: Double {
        TextureAllocatorSnapshot(
            allocationStrategy: allocationStrategy,
            requestedAllocationStrategy: requestedAllocationStrategy,
            allocationFallbackReason: allocationFallbackReason,
            textureRequestCount: textureRequestCount,
            textureReuseHitCount: textureReuseHitCount,
            heapBackedAllocationCount: heapBackedAllocationCount,
            allocatorDecisions: allocatorDecisions
        ).textureReuseHitRatio
    }

    public var allocationResolution: TextureAllocationResolution {
        TextureAllocationResolution(
            requested: requestedAllocationStrategy ?? allocationStrategy,
            resolved: allocationStrategy,
            fallbackReason: allocationFallbackReason
        )
    }
}

enum RenderStageMergeClass: String, Sendable, Codable, Equatable, Hashable {
    case pointCompute
    case renderPipeline
    case blitPass
}

struct RenderStage: Sendable, Codable, Equatable, Hashable {
    let index: Int
    let stageKind: RenderStageKind
    let mergeClass: RenderStageMergeClass?
    let nodeIndices: [Int]
    let kinds: [RenderNodeKind]
    let filterCount: Int
    let breaksFusion: Bool
    let inputSize: C7Size
    let outputSize: C7Size
    let boundaryReason: RenderStageBoundaryReason?
    let containsReadbackBoundary: Bool
    let createsDestinationTexture: Bool
    let containsLocalEffectComposite: Bool
    let containsTransitionKernel: Bool
    let containsDerivativeResize: Bool

    init(index: Int,
         stageKind: RenderStageKind,
         mergeClass: RenderStageMergeClass?,
         nodeIndices: [Int],
         kinds: [RenderNodeKind],
         filterCount: Int,
         breaksFusion: Bool,
         inputSize: C7Size,
         outputSize: C7Size,
         boundaryReason: RenderStageBoundaryReason?,
         containsReadbackBoundary: Bool,
         createsDestinationTexture: Bool,
         containsLocalEffectComposite: Bool,
         containsTransitionKernel: Bool,
         containsDerivativeResize: Bool) {
        self.index = index
        self.stageKind = stageKind
        self.mergeClass = mergeClass
        self.nodeIndices = nodeIndices
        self.kinds = kinds
        self.filterCount = filterCount
        self.breaksFusion = breaksFusion
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.boundaryReason = boundaryReason
        self.containsReadbackBoundary = containsReadbackBoundary
        self.createsDestinationTexture = createsDestinationTexture
        self.containsLocalEffectComposite = containsLocalEffectComposite
        self.containsTransitionKernel = containsTransitionKernel
        self.containsDerivativeResize = containsDerivativeResize
    }
}

struct RenderNodeDiagnostic: Sendable, Codable, Equatable, Hashable {
    let index: Int
    let name: String
    let kind: RenderNodeKind
    let inputSize: C7Size
    let outputSize: C7Size
    let breaksFusion: Bool
    let parameterSummary: [String: String]

    init(index: Int,
         name: String,
         kind: RenderNodeKind,
         inputSize: C7Size,
         outputSize: C7Size,
         breaksFusion: Bool,
         parameterSummary: [String: String]) {
        self.index = index
        self.name = name
        self.kind = kind
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.breaksFusion = breaksFusion
        self.parameterSummary = parameterSummary
    }
}

public struct RenderPlanDiagnostics: Sendable, Codable, Equatable, Hashable {
    public let profile: RenderProfile
    public let derivative: ImageDerivativeSpec
    public let graphFingerprint: String
    public let sourceKind: String?
    public let graphNodeCount: Int
    public let graphEdgeCount: Int
    public let optimizedGraphNodeCount: Int
    public let graphOptimizationDecisions: [String]
    public let persistentBoundaryCount: Int
    public let transientReuseCandidateCount: Int
    public let sharedDependencyNodeCount: Int
    public let inputSize: C7Size
    public let outputSize: C7Size
    public let containsBoundary: Bool
    public let requiresCompletedGPUWork: Bool
    public let stageCount: Int
    public let compilationSource: RenderCompilationSource
    public let imageCachePolicy: ImageCachePolicy
    public let samplerDescriptor: ImageSamplerDescriptor
    public let samplerExecutionCoverage: SamplerExecutionCoverage
    public let containsLocalEffectComposite: Bool
    public let containsTransitionKernel: Bool
    public let containsDerivativeResize: Bool
    public let optimizationPlan: RenderOptimizationPlan
    public let outputContract: RenderOutputContract
    public let inputColorSpace: ImageColorSpaceContract
    public let outputColorSpace: ImageColorSpaceContract
    public let inputAlphaType: AlphaType?
    public let outputAlphaType: AlphaType?
    public let inputPixelFormat: PixelFormatContract
    public let inputBridgePolicy: PixelBufferBridgePolicy?
    public let inputYCbCrDecodeContract: YCbCrDecodeContract?
    public let outputPixelFormat: PixelFormatContract
    public let inputColorConversionCount: Int
    public let inputPixelFormatConversionCount: Int
    public let inputAlphaConversionCount: Int
    public let inputDirectPlaneBridgeCount: Int
    public let alphaConversionCount: Int
    public let colorConversionCount: Int
    public let pixelFormatConversionCount: Int
    public let lossyConversionCount: Int
    let nodes: [RenderNodeDiagnostic]
    let stages: [RenderStage]

    init(profile: RenderProfile,
         derivative: ImageDerivativeSpec,
         graphFingerprint: String,
         sourceKind: String?,
         graphNodeCount: Int,
         graphEdgeCount: Int,
         optimizedGraphNodeCount: Int,
         graphOptimizationDecisions: [String],
         persistentBoundaryCount: Int,
         transientReuseCandidateCount: Int,
         sharedDependencyNodeCount: Int,
         inputSize: C7Size,
         outputSize: C7Size,
         containsBoundary: Bool,
         requiresCompletedGPUWork: Bool,
         stageCount: Int,
         compilationSource: RenderCompilationSource,
         imageCachePolicy: ImageCachePolicy,
         samplerDescriptor: ImageSamplerDescriptor,
         samplerExecutionCoverage: SamplerExecutionCoverage,
         containsLocalEffectComposite: Bool,
         containsTransitionKernel: Bool,
         containsDerivativeResize: Bool,
         optimizationPlan: RenderOptimizationPlan,
         outputContract: RenderOutputContract,
         inputColorSpace: ImageColorSpaceContract,
         outputColorSpace: ImageColorSpaceContract,
         inputAlphaType: AlphaType?,
         outputAlphaType: AlphaType?,
         inputPixelFormat: PixelFormatContract,
         inputBridgePolicy: PixelBufferBridgePolicy? = nil,
         inputYCbCrDecodeContract: YCbCrDecodeContract? = nil,
         outputPixelFormat: PixelFormatContract,
         inputColorConversionCount: Int,
         inputPixelFormatConversionCount: Int,
         inputAlphaConversionCount: Int,
         inputDirectPlaneBridgeCount: Int = 0,
         alphaConversionCount: Int,
         colorConversionCount: Int,
         pixelFormatConversionCount: Int,
         lossyConversionCount: Int,
         nodes: [RenderNodeDiagnostic],
         stages: [RenderStage]) {
        self.profile = profile
        self.derivative = derivative
        self.graphFingerprint = graphFingerprint
        self.sourceKind = sourceKind
        self.graphNodeCount = graphNodeCount
        self.graphEdgeCount = graphEdgeCount
        self.optimizedGraphNodeCount = optimizedGraphNodeCount
        self.graphOptimizationDecisions = graphOptimizationDecisions
        self.persistentBoundaryCount = persistentBoundaryCount
        self.transientReuseCandidateCount = transientReuseCandidateCount
        self.sharedDependencyNodeCount = sharedDependencyNodeCount
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.containsBoundary = containsBoundary
        self.requiresCompletedGPUWork = requiresCompletedGPUWork
        self.stageCount = stageCount
        self.compilationSource = compilationSource
        self.imageCachePolicy = imageCachePolicy
        self.samplerDescriptor = samplerDescriptor
        self.samplerExecutionCoverage = samplerExecutionCoverage
        self.containsLocalEffectComposite = containsLocalEffectComposite
        self.containsTransitionKernel = containsTransitionKernel
        self.containsDerivativeResize = containsDerivativeResize
        self.optimizationPlan = optimizationPlan
        self.outputContract = outputContract
        self.inputColorSpace = inputColorSpace
        self.outputColorSpace = outputColorSpace
        self.inputAlphaType = inputAlphaType
        self.outputAlphaType = outputAlphaType
        self.inputPixelFormat = inputPixelFormat
        self.inputBridgePolicy = inputBridgePolicy
        self.inputYCbCrDecodeContract = inputYCbCrDecodeContract
        self.outputPixelFormat = outputPixelFormat
        self.inputColorConversionCount = inputColorConversionCount
        self.inputPixelFormatConversionCount = inputPixelFormatConversionCount
        self.inputAlphaConversionCount = inputAlphaConversionCount
        self.inputDirectPlaneBridgeCount = inputDirectPlaneBridgeCount
        self.alphaConversionCount = alphaConversionCount
        self.colorConversionCount = colorConversionCount
        self.pixelFormatConversionCount = pixelFormatConversionCount
        self.lossyConversionCount = lossyConversionCount
        self.nodes = nodes
        self.stages = stages
    }

    public var summary: String {
        let stageSummary = stages
            .map { stage in
                let kinds = stage.kinds.map(\.rawValue).joined(separator: ",")
                return "s\(stage.index)[\(kinds)]x\(stage.filterCount)\(stage.breaksFusion ? "*" : "")"
            }
            .joined(separator: " -> ")
        return [
            "profile=\(String(describing: profile))",
            "derivative=\(derivative.name)",
            "input=\(inputSize.width)x\(inputSize.height)",
            "output=\(outputSize.width)x\(outputSize.height)",
            "graph=\(graphFingerprint)",
            "graphNodes=\(graphNodeCount)",
            "graphEdges=\(graphEdgeCount)",
            "optimizedGraphNodes=\(optimizedGraphNodeCount)",
            "persistentBoundaries=\(persistentBoundaryCount)",
            "reuseCandidates=\(transientReuseCandidateCount)",
            "sharedDependencies=\(sharedDependencyNodeCount)",
            "nodes=\(nodes.count)",
            "stages=\(stageCount)",
            "boundary=\(containsBoundary ? 1 : 0)",
            "readback=\(requiresCompletedGPUWork ? 1 : 0)",
            "source=\(compilationSource.rawValue)",
            "origin=\(sourceKind ?? "unknown")",
            "cachePolicy=\(imageCachePolicy.rawValue)",
            "sampler=\(samplerDescriptor.fingerprint)",
            "samplerCoverage=\(samplerExecutionCoverage.mode.rawValue)",
            "samplerCoveredFilters=\(samplerExecutionCoverage.coveredFilterTypes.joined(separator: ","))",
            "samplerMetadataOnlyFilters=\(samplerExecutionCoverage.metadataOnlyFilterTypes.joined(separator: ","))",
            "intermediateTextures=\(optimizationPlan.intermediateTextureCount)",
            "reusableTextures=\(optimizationPlan.reusableTextureCount)",
            "mergedStages=\(optimizationPlan.mergedStageCount)",
            "fusionEligibleNodes=\(optimizationPlan.fusionEligibleNodeCount)",
            "transientStages=\(optimizationPlan.transientStageCount)",
            "renderStages=\(optimizationPlan.renderStageCount)",
            "transientBytes=\(optimizationPlan.estimatedTransientByteCount)",
            "prewarm=\(optimizationPlan.prewarmReservations.count)",
            "lifecycle=\(optimizationPlan.lifecycleDecisions.count)",
            "formatConversions=\(optimizationPlan.formatConversionCount)",
            "allocator=\(optimizationPlan.allocationStrategy.rawValue)",
            optimizationPlan.requestedAllocationStrategy.map { "requestedAllocator=\($0.rawValue)" } ?? "requestedAllocator=none",
            "allocatorFallback=\(optimizationPlan.allocationFallbackReason ?? "none")",
            "textureRequests=\(optimizationPlan.textureRequestCount)",
            "textureReuseHits=\(optimizationPlan.textureReuseHitCount)",
            "textureReuseRatio=\(String(format: "%.3f", optimizationPlan.textureReuseHitRatio))",
            "heapBacked=\(optimizationPlan.heapBackedAllocationCount)",
            "inputColorConversions=\(inputColorConversionCount)",
            "inputPixelFormatConversions=\(inputPixelFormatConversionCount)",
            "inputAlphaConversions=\(inputAlphaConversionCount)",
            "inputDirectPlanes=\(inputDirectPlaneBridgeCount)",
            "inputColor=\(inputColorSpace.name)",
            "outputColor=\(outputColorSpace.name)",
            "inputAlpha=\(inputAlphaType?.rawValue ?? "none")",
            "outputAlpha=\(outputAlphaType?.rawValue ?? "none")",
            "inputPixel=\(inputPixelFormat.name)",
            "inputBridgePolicy=\(inputBridgePolicy?.rawValue ?? "none")",
            "inputYCbCrDecode=\(inputYCbCrDecodeContract?.fingerprint ?? "none")",
            "inputPixelPrecision=\(inputPixelPrecision.rawValue)",
            "inputHDRFriendly=\(inputIsHDRFriendly ? 1 : 0)",
            "outputPixel=\(outputPixelFormat.name)",
            "alphaContract=\(outputContract.alpha)",
            "colorGamut=\(outputContract.colorSpace.gamut.rawValue)",
            "transfer=\(outputContract.colorSpace.transferFunction.rawValue)",
            "pixelPrecision=\(outputContract.pixelFormat.precision.rawValue)",
            "outputAttachments=\(outputAttachmentCount)",
            "outputAttachmentIndices=\(outputContract.attachments.map { String($0.index) }.joined(separator: ","))",
            "outputAttachmentSemantics=\(outputContract.attachments.map { $0.semantic.rawValue }.joined(separator: ","))",
            "outputAttachmentPixels=\(outputContract.attachments.map { $0.pixelFormat.name }.joined(separator: ","))",
            "outputAttachmentHDR=\(outputContract.attachments.map { $0.isHDRFriendlyOutput ? "1" : "0" }.joined(separator: ","))",
            "outputAttachmentDebugLabels=\(outputContract.attachmentDebugPolicies.map(\.label).joined(separator: ","))",
            "outputAttachmentDebugViews=\(outputContract.attachmentDebugPolicies.map { $0.interpretation.rawValue }.joined(separator: ","))",
            "outputAttachmentReadbackPixels=\(outputContract.attachmentDebugPolicies.map { $0.preferredReadbackPixelFormat.name }.joined(separator: ","))",
            "outputAttachmentMonochromePreview=\(outputContract.attachmentDebugPolicies.map { $0.prefersMonochromePreview ? "1" : "0" }.joined(separator: ","))",
            "lossyConversions=\(lossyConversionCount)",
            "hdrFriendly=\(outputContract.hasHDRFriendlyAttachment ? 1 : 0)",
            "plan=\(stageSummary)"
        ].joined(separator: " ")
    }

    public var inputPixelPrecision: PixelPrecision {
        inputPixelFormat.precision
    }

    public var inputIsHighPrecision: Bool {
        inputPixelFormat.isHighPrecision
    }

    public var inputIsHDRFriendly: Bool {
        inputPixelFormat.isHighPrecision || inputColorSpace.isWideGamut || inputColorSpace.isHDRTransfer
    }

    public var outputAttachmentCount: Int {
        outputContract.attachmentCount
    }

    public var outputHasMultipleAttachments: Bool {
        outputContract.hasMultipleAttachments
    }

    public var outputAttachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy] {
        outputContract.attachmentDebugPolicies
    }

    public func withImageCachePolicy(_ policy: ImageCachePolicy) -> RenderPlanDiagnostics {
        let plan = GraphOptimizer.makeOptimizationPlan(
            stages: stages,
            nodeDiagnostics: nodes,
            outputContract: outputContract,
            imageCachePolicy: policy,
            inputPixelFormat: inputPixelFormat
        )
        return RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            graphFingerprint: graphFingerprint,
            sourceKind: sourceKind,
            graphNodeCount: graphNodeCount,
            graphEdgeCount: graphEdgeCount,
            optimizedGraphNodeCount: optimizedGraphNodeCount,
            graphOptimizationDecisions: graphOptimizationDecisions,
            persistentBoundaryCount: persistentBoundaryCount,
            transientReuseCandidateCount: transientReuseCandidateCount,
            sharedDependencyNodeCount: sharedDependencyNodeCount,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            stageCount: stageCount,
            compilationSource: compilationSource,
            imageCachePolicy: policy,
            samplerDescriptor: samplerDescriptor,
            samplerExecutionCoverage: samplerExecutionCoverage,
            containsLocalEffectComposite: containsLocalEffectComposite,
            containsTransitionKernel: containsTransitionKernel,
            containsDerivativeResize: containsDerivativeResize,
            optimizationPlan: plan,
            outputContract: outputContract,
            inputColorSpace: inputColorSpace,
            outputColorSpace: outputColorSpace,
            inputAlphaType: inputAlphaType,
            outputAlphaType: outputAlphaType,
            inputPixelFormat: inputPixelFormat,
            inputBridgePolicy: inputBridgePolicy,
            inputYCbCrDecodeContract: inputYCbCrDecodeContract,
            outputPixelFormat: outputPixelFormat,
            inputColorConversionCount: inputColorConversionCount,
            inputPixelFormatConversionCount: inputPixelFormatConversionCount,
            inputAlphaConversionCount: inputAlphaConversionCount,
            inputDirectPlaneBridgeCount: inputDirectPlaneBridgeCount,
            alphaConversionCount: alphaConversionCount,
            colorConversionCount: colorConversionCount,
            pixelFormatConversionCount: pixelFormatConversionCount,
            lossyConversionCount: lossyConversionCount,
            nodes: nodes,
            stages: stages
        )
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> RenderPlanDiagnostics {
        RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            graphFingerprint: graphFingerprint,
            sourceKind: sourceKind,
            graphNodeCount: graphNodeCount,
            graphEdgeCount: graphEdgeCount,
            optimizedGraphNodeCount: optimizedGraphNodeCount,
            graphOptimizationDecisions: graphOptimizationDecisions,
            persistentBoundaryCount: persistentBoundaryCount,
            transientReuseCandidateCount: transientReuseCandidateCount,
            sharedDependencyNodeCount: sharedDependencyNodeCount,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            stageCount: stageCount,
            compilationSource: compilationSource,
            imageCachePolicy: imageCachePolicy,
            samplerDescriptor: descriptor,
            samplerExecutionCoverage: samplerExecutionCoverage,
            containsLocalEffectComposite: containsLocalEffectComposite,
            containsTransitionKernel: containsTransitionKernel,
            containsDerivativeResize: containsDerivativeResize,
            optimizationPlan: optimizationPlan,
            outputContract: outputContract,
            inputColorSpace: inputColorSpace,
            outputColorSpace: outputColorSpace,
            inputAlphaType: inputAlphaType,
            outputAlphaType: outputAlphaType,
            inputPixelFormat: inputPixelFormat,
            inputBridgePolicy: inputBridgePolicy,
            inputYCbCrDecodeContract: inputYCbCrDecodeContract,
            outputPixelFormat: outputPixelFormat,
            inputColorConversionCount: inputColorConversionCount,
            inputPixelFormatConversionCount: inputPixelFormatConversionCount,
            inputAlphaConversionCount: inputAlphaConversionCount,
            inputDirectPlaneBridgeCount: inputDirectPlaneBridgeCount,
            alphaConversionCount: alphaConversionCount,
            colorConversionCount: colorConversionCount,
            pixelFormatConversionCount: pixelFormatConversionCount,
            lossyConversionCount: lossyConversionCount,
            nodes: nodes,
            stages: stages
        )
    }

    public func jsonData(prettyPrinted: Bool = false,
                         sortedKeys: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting.insert(.prettyPrinted)
        }
        if sortedKeys {
            encoder.outputFormatting.insert(.sortedKeys)
        }
        return try encoder.encode(self)
    }

    public func jsonString(prettyPrinted: Bool = false,
                           sortedKeys: Bool = true) throws -> String {
        let data = try jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HarbethError.configurationInvalid("RenderPlanDiagnostics JSON encoding is not valid UTF-8.")
        }
        return string
    }
}

struct RenderPlan {
    let graph: RenderGraph
    let profile: RenderProfile
    let requiresCompletedGPUWork: Bool
    let containsBoundary: Bool
    let optimizedStages: [RenderStage]
    let diagnostics: RenderPlanDiagnostics

    init(graph: RenderGraph,
         profile: RenderProfile,
         derivative: ImageDerivativeSpec,
         inputSize: C7Size,
         outputSize: C7Size,
         nodeDiagnostics: [RenderNodeDiagnostic],
         compilationSource: RenderCompilationSource,
         outputContract: RenderOutputContract = .preserveInput,
         imageCachePolicy: ImageCachePolicy = .transient,
         samplerDescriptor: ImageSamplerDescriptor = .default,
         samplerExecutionCoverage: SamplerExecutionCoverage = SamplerExecutionCoverage(mode: .notApplicable),
         sourceDescriptor: ImageSourceDescriptor? = nil,
         auxiliaryInputDescriptor: ImageSourceDescriptor? = nil,
         inputColorConversionCount: Int? = nil,
         inputPixelFormatConversionCount: Int? = nil,
         inputAlphaConversionCount: Int? = nil,
         imageGraph: ImageGraph? = nil,
         graphOptimizationDecisions: [String] = []) {
        self.graph = graph
        self.profile = profile
        let requiresCompletedGPUWork = profile.requiresCompletedGPUWorkBeforeReadback
        let containsBoundary = graph.nodes.contains(where: { $0.kind == .boundary || $0.breaksFusion })
        self.requiresCompletedGPUWork = requiresCompletedGPUWork
        self.containsBoundary = containsBoundary
        self.optimizedStages = GraphOptimizer.optimize(
            graph: graph,
            nodeDiagnostics: nodeDiagnostics,
            profile: profile
        )
        let sourceDerivedInputColorConversions = RenderPlan.resolveInputColorConversionCount(from: sourceDescriptor)
        let sourceDerivedInputPixelFormatConversions = RenderPlan.resolveInputPixelFormatConversionCount(from: sourceDescriptor)
        let sourceDirectPlaneBridgeCount = RenderPlan.resolveInputDirectPlaneBridgeCount(from: sourceDescriptor)
        let auxiliaryInputColorConversions = RenderPlan.resolveInputColorConversionCount(from: auxiliaryInputDescriptor)
        let auxiliaryInputPixelFormatConversions = RenderPlan.resolveInputPixelFormatConversionCount(from: auxiliaryInputDescriptor)
        let auxiliaryDirectPlaneBridgeCount = RenderPlan.resolveInputDirectPlaneBridgeCount(from: auxiliaryInputDescriptor)
        let resolvedInputColorConversionCount = inputColorConversionCount ?? (sourceDerivedInputColorConversions + auxiliaryInputColorConversions)
        let resolvedInputPixelFormatConversionCount = inputPixelFormatConversionCount ?? (sourceDerivedInputPixelFormatConversions + auxiliaryInputPixelFormatConversions)
        let resolvedInputAlphaConversionCount = inputAlphaConversionCount ?? 0
        let resolvedInputDirectPlaneBridgeCount = sourceDirectPlaneBridgeCount + auxiliaryDirectPlaneBridgeCount
        let resolvedInputBridgePolicy = sourceDescriptor?.pixelBufferBridgePolicy ?? auxiliaryInputDescriptor?.pixelBufferBridgePolicy
        let resolvedInputYCbCrDecodeContract = sourceDescriptor?.yCbCrDecodeContract ?? auxiliaryInputDescriptor?.yCbCrDecodeContract
        let resolvedInputColorSpace = RenderPlan.resolveInputColorSpace(
            primary: sourceDescriptor,
            auxiliary: auxiliaryInputDescriptor
        )
        let resolvedInputPixelFormat = RenderPlan.resolveInputPixelFormat(from: sourceDescriptor)
        let optimizationPlan = GraphOptimizer.makeOptimizationPlan(
            stages: optimizedStages,
            nodeDiagnostics: nodeDiagnostics,
            outputContract: outputContract,
            imageCachePolicy: imageCachePolicy,
            inputPixelFormat: resolvedInputPixelFormat
        )
        let resolvedOutputPixelFormat = outputContract.pixelFormat.preservesInput
            ? (resolvedInputPixelFormat.preservesInput ? .rgba8Unorm : resolvedInputPixelFormat)
            : outputContract.pixelFormat
        let resolvedOutputColorSpace = outputContract.colorSpace
        let resolvedOutputAlphaType = outputContract.alpha.expectedAlphaType ?? sourceDescriptor?.alphaType
        let resolvedLossyConversionCount = outputContract.allowsLossyConversion ? 1 : 0
        let resolvedGraphNodeCount = imageGraph?.nodeCount ?? max(nodeDiagnostics.count, graph.nodes.count)
        let resolvedGraphEdgeCount = imageGraph?.edgeCount ?? max(resolvedGraphNodeCount - 1, 0)
        let resolvedOptimizedGraphNodeCount = imageGraph?.nodeCount ?? resolvedGraphNodeCount
        let resolvedPersistentBoundaryCount = imageGraph?.persistentBoundaryCount ?? (containsBoundary ? 1 : 0)
        let resolvedTransientReuseCandidateCount = imageGraph?.transientReuseCandidateCount ?? max(nodeDiagnostics.count - 1, 0)
        let resolvedSharedDependencyNodeCount = imageGraph?.sharedDependencyNodeCount ?? 0
        self.diagnostics = RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            graphFingerprint: RenderPlanDiagnostics.makeGraphFingerprint(
                nodes: nodeDiagnostics,
                stages: optimizedStages,
                compilationSource: compilationSource
            ),
            sourceKind: sourceDescriptor?.kind,
            graphNodeCount: resolvedGraphNodeCount,
            graphEdgeCount: resolvedGraphEdgeCount,
            optimizedGraphNodeCount: resolvedOptimizedGraphNodeCount,
            graphOptimizationDecisions: graphOptimizationDecisions,
            persistentBoundaryCount: resolvedPersistentBoundaryCount,
            transientReuseCandidateCount: resolvedTransientReuseCandidateCount,
            sharedDependencyNodeCount: resolvedSharedDependencyNodeCount,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            stageCount: optimizedStages.count,
            compilationSource: compilationSource,
            imageCachePolicy: imageCachePolicy,
            samplerDescriptor: samplerDescriptor,
            samplerExecutionCoverage: samplerExecutionCoverage,
            containsLocalEffectComposite: optimizedStages.contains(where: \.containsLocalEffectComposite),
            containsTransitionKernel: optimizedStages.contains(where: \.containsTransitionKernel),
            containsDerivativeResize: optimizedStages.contains(where: \.containsDerivativeResize),
            optimizationPlan: optimizationPlan,
            outputContract: outputContract,
            inputColorSpace: resolvedInputColorSpace,
            outputColorSpace: resolvedOutputColorSpace,
            inputAlphaType: sourceDescriptor?.alphaType,
            outputAlphaType: resolvedOutputAlphaType,
            inputPixelFormat: resolvedInputPixelFormat,
            inputBridgePolicy: resolvedInputBridgePolicy,
            inputYCbCrDecodeContract: resolvedInputYCbCrDecodeContract,
            outputPixelFormat: resolvedOutputPixelFormat,
            inputColorConversionCount: resolvedInputColorConversionCount,
            inputPixelFormatConversionCount: resolvedInputPixelFormatConversionCount,
            inputAlphaConversionCount: resolvedInputAlphaConversionCount,
            inputDirectPlaneBridgeCount: resolvedInputDirectPlaneBridgeCount,
            alphaConversionCount: outputContract.requiresAlphaConversion ? 1 : 0,
            colorConversionCount: outputContract.requiresColorSpaceConversion ? 1 : 0,
            pixelFormatConversionCount: outputContract.requiresPixelFormatConversion ? max(optimizationPlan.formatConversionCount, 1) : optimizationPlan.formatConversionCount,
            lossyConversionCount: resolvedLossyConversionCount,
            nodes: nodeDiagnostics,
            stages: optimizedStages
        )
    }

    public var debugSummary: String {
        diagnostics.summary
    }
}

private extension RenderPlan {
    static func resolveInputColorSpace(primary descriptor: ImageSourceDescriptor?,
                                       auxiliary auxiliaryDescriptor: ImageSourceDescriptor?) -> ImageColorSpaceContract {
        if let colorSpace = resolveAttachmentColorSpace(from: descriptor)
            ?? resolveAttachmentColorSpace(from: auxiliaryDescriptor) {
            return colorSpace
        }
        return .preserveInput
    }

    static func resolveAttachmentColorSpace(from descriptor: ImageSourceDescriptor?) -> ImageColorSpaceContract? {
        descriptor?.pixelBufferContract?.attachmentColorSpace
            ?? descriptor?.sampleBufferContract?.pixelBufferContract?.attachmentColorSpace
    }

    static func sourceRequiresYCbCrConversion(_ descriptor: ImageSourceDescriptor?) -> Bool {
        descriptor?.pixelBufferBridgePlan?.requiresColorConversion == true
            || descriptor?.sampleBufferContract?.pixelBufferContract?.requiresYCbCrConversion == true
    }

    static func resolveInputColorConversionCount(from descriptor: ImageSourceDescriptor?) -> Int {
        guard let descriptor else {
            return 0
        }
        if let bridgePlan = descriptor.pixelBufferBridgePlan,
           bridgePlan.requiresColorConversion {
            return 1
        }
        if descriptor.sampleBufferContract?.pixelBufferContract?.requiresYCbCrConversion == true {
            return 1
        }
        return 0
    }

    static func resolveInputPixelFormatConversionCount(from descriptor: ImageSourceDescriptor?) -> Int {
        guard let descriptor else {
            return 0
        }
        if let bridgePlan = descriptor.pixelBufferBridgePlan,
           bridgePlan.loadStrategy != .directMetalTexture {
            return 1
        }
        if descriptor.sampleBufferContract?.pixelBufferContract?.colorModel == .yCbCrBiPlanar
            || descriptor.sampleBufferContract?.pixelBufferContract?.colorModel == .yCbCrTriPlanar {
            return 1
        }
        return 0
    }

    static func resolveInputDirectPlaneBridgeCount(from descriptor: ImageSourceDescriptor?) -> Int {
        guard let descriptor else {
            return 0
        }
        if let bridgePlan = descriptor.pixelBufferBridgePlan {
            return bridgePlan.directPlaneBridgeCount
        }
        return descriptor.sampleBufferContract?.frameContract.directPlaneBridgeCount ?? 0
    }

    static func resolveInputPixelFormat(from descriptor: ImageSourceDescriptor?) -> PixelFormatContract {
        if let pixelFormat = descriptor?.pixelBufferBridgePlan?.contract.preferredMetalPixelFormat {
            return PixelFormatContract(pixelFormat: pixelFormat, preservesInput: true)
        }
        return .preserveInput
    }
}

enum GraphOptimizer {
    static func makeOptimizationPlan(stages: [RenderStage],
                                     nodeDiagnostics: [RenderNodeDiagnostic],
                                     outputContract: RenderOutputContract = .preserveInput,
                                     imageCachePolicy: ImageCachePolicy = .transient,
                                     inputPixelFormat: PixelFormatContract = .preserveInput) -> RenderOptimizationPlan {
        let intermediateTextureCount = max(nodeDiagnostics.count - 1, 0)
        let readbackBoundaryCount = stages.filter(\.containsReadbackBoundary).count
        let destinationTextureCreationCount = stages.filter(\.createsDestinationTexture).count
        let formatConversionCount = outputContract.requiresPixelFormatConversion ? 1 : 0
        let mergedStageCount = stages.filter { $0.filterCount > 1 && $0.mergeClass != nil }.count
        let fusionEligibleNodeCount = stages
            .filter { $0.mergeClass != nil }
            .reduce(0) { $0 + $1.filterCount }
        let transientStageCount = stages.filter { stage in
            stage.createsDestinationTexture && stage.index < stages.count - 1
        }.count
        let renderStageCount = stages.filter { $0.stageKind == .render }.count
        let lifecycleDecisions = makeLifecycleDecisions(stages: stages)
        let prewarmReservations = makePrewarmReservations(
            lifecycleDecisions: lifecycleDecisions,
            outputContract: outputContract,
            inputPixelFormat: inputPixelFormat
        )
        let reusableTextureCount = lifecycleDecisions.filter { $0.action == .reuseTransient }.count
        let estimatedTransientByteCount = lifecycleDecisions
            .filter { $0.action == .reuseTransient || $0.action == .allocateTransient }
            .reduce(0) { partial, decision in
                partial + estimatedByteCount(
                    for: decision.size,
                    pixelFormat: pixelFormat(
                        for: decision,
                        outputContract: outputContract,
                        inputPixelFormat: inputPixelFormat
                    )
                )
            }
        let estimatedPersistentByteCount = lifecycleDecisions
            .filter { $0.action == .allocatePersistentOutput || $0.action == .preserveForReadback }
            .reduce(0) { partial, decision in
                partial + estimatedByteCount(
                    for: decision.size,
                    pixelFormat: pixelFormat(
                        for: decision,
                        outputContract: outputContract,
                        inputPixelFormat: inputPixelFormat
                    )
                )
            }
        var decisions: [String] = []
        if intermediateTextureCount > 0 {
            decisions.append("reuseTransientIntermediateTextures")
        }
        if reusableTextureCount > 0 {
            decisions.append("planTransientTextureReuse")
        }
        if mergedStageCount > 0 {
            decisions.append("mergeCompatibleStages")
        }
        if stages.contains(where: \.containsDerivativeResize) {
            decisions.append("keepDerivativeResizeAtTerminalStage")
        }
        if readbackBoundaryCount > 0 {
            decisions.append("preserveReadbackBoundary")
        }
        if formatConversionCount > 0 {
            decisions.append("recordPixelFormatConversion")
        }
        if imageCachePolicy == .persistent {
            decisions.append("preservePersistentImageNode")
        }
        if inputPixelFormat.isHighPrecision,
           prewarmReservations.contains(where: {
               resolvedReservationPixelFormat(
                   preferred: $0.pixelFormat,
                   fallback: inputPixelFormat
               ).metalPixelFormat == inputPixelFormat.metalPixelFormat
           }) {
            decisions.append("preserveInputPixelFormatForReservations")
        }
        if prewarmReservations.contains(where: {
            $0.reason == .transientReuse && $0.stageIndices.count > $0.count
        }) {
            decisions.append("capTransientReusePrewarmToDoubleBuffer")
        }
        if decisions.isEmpty {
            decisions.append("singleStageNoOptimizationNeeded")
        }
        let allocatorSnapshot = Shared.shared.defaultTextureAllocator.makeSnapshot()
        return RenderOptimizationPlan(
            intermediateTextureCount: intermediateTextureCount,
            reusableTextureCount: reusableTextureCount,
            persistentOutputCount: 1,
            mergedStageCount: mergedStageCount,
            fusionEligibleNodeCount: fusionEligibleNodeCount,
            transientStageCount: transientStageCount,
            renderStageCount: renderStageCount,
            estimatedTransientByteCount: estimatedTransientByteCount,
            estimatedPersistentByteCount: estimatedPersistentByteCount,
            readbackBoundaryCount: readbackBoundaryCount,
            formatConversionCount: formatConversionCount,
            destinationTextureCreationCount: destinationTextureCreationCount,
            allocationStrategy: allocatorSnapshot.allocationStrategy,
            requestedAllocationStrategy: allocatorSnapshot.requestedAllocationStrategy,
            allocationFallbackReason: allocatorSnapshot.allocationFallbackReason,
            textureRequestCount: allocatorSnapshot.textureRequestCount,
            textureReuseHitCount: allocatorSnapshot.textureReuseHitCount,
            heapBackedAllocationCount: allocatorSnapshot.heapBackedAllocationCount,
            prewarmReservations: prewarmReservations,
            lifecycleDecisions: lifecycleDecisions,
            decisions: decisions,
            allocatorDecisions: allocatorSnapshot.allocatorDecisions
        )
    }

    private static func makeLifecycleDecisions(stages: [RenderStage]) -> [RenderTextureLifecycleDecision] {
        guard stages.isEmpty == false else { return [] }
        return stages.map { stage in
            let isLast = stage.index == stages.count - 1
            if isLast {
                return RenderTextureLifecycleDecision(
                    stageIndex: stage.index,
                    action: stage.containsReadbackBoundary ? .preserveForReadback : .allocatePersistentOutput,
                    size: stage.outputSize,
                    reason: stage.containsReadbackBoundary ? "terminalReadbackBoundary" : "terminalOutput"
                )
            }
            if stage.containsReadbackBoundary {
                return RenderTextureLifecycleDecision(
                    stageIndex: stage.index,
                    action: .preserveForReadback,
                    size: stage.outputSize,
                    reason: "readbackBoundary"
                )
            }
            if stage.createsDestinationTexture {
                return RenderTextureLifecycleDecision(
                    stageIndex: stage.index,
                    action: .reuseTransient,
                    size: stage.outputSize,
                    reason: "safeTransientAfterStage"
                )
            }
            return RenderTextureLifecycleDecision(
                stageIndex: stage.index,
                action: .allocateTransient,
                size: stage.outputSize,
                reason: "nonWritingStage"
            )
        }
    }

    private static func estimatedByteCount(for size: C7Size,
                                           pixelFormat: PixelFormatContract) -> Int {
        max(size.width, 0) * max(size.height, 0) * bytesPerPixel(for: pixelFormat)
    }

    private static func makePrewarmReservations(lifecycleDecisions: [RenderTextureLifecycleDecision],
                                                outputContract: RenderOutputContract,
                                                inputPixelFormat: PixelFormatContract) -> [RenderTextureReservation] {
        var grouped: [String: RenderTextureReservation] = [:]
        for decision in lifecycleDecisions {
            let reason: RenderTextureReservationReason?
            let pixelFormat: PixelFormatContract
            switch decision.action {
            case .reuseTransient:
                reason = .transientReuse
                pixelFormat = resolvedReservationPixelFormat(
                    preferred: .preserveInput,
                    fallback: inputPixelFormat
                )
            case .allocatePersistentOutput:
                reason = .persistentOutput
                pixelFormat = resolvedReservationPixelFormat(
                    preferred: outputContract.pixelFormat,
                    fallback: inputPixelFormat
                )
            case .preserveForReadback:
                reason = .readbackOutput
                pixelFormat = resolvedReservationPixelFormat(
                    preferred: outputContract.pixelFormat,
                    fallback: inputPixelFormat
                )
            case .allocateTransient:
                reason = nil
                pixelFormat = resolvedReservationPixelFormat(
                    preferred: .preserveInput,
                    fallback: inputPixelFormat
                )
            }
            guard let reason else { continue }
            let key = [
                reason.rawValue,
                "\(decision.size.width)x\(decision.size.height)",
                pixelFormat.fingerprint
            ].joined(separator: "|")
            if let existing = grouped[key] {
                let nextCount: Int
                if existing.reason == .transientReuse {
                    nextCount = min(existing.count + 1, 2)
                } else {
                    nextCount = existing.count + 1
                }
                grouped[key] = RenderTextureReservation(
                    stageIndices: existing.stageIndices + [decision.stageIndex],
                    size: existing.size,
                    pixelFormat: existing.pixelFormat,
                    reason: existing.reason,
                    count: nextCount
                )
            } else {
                grouped[key] = RenderTextureReservation(
                    stageIndices: [decision.stageIndex],
                    size: decision.size,
                    pixelFormat: pixelFormat,
                    reason: reason
                )
            }
        }
        return grouped.values.sorted { lhs, rhs in
            if lhs.reason != rhs.reason {
                return lhs.reason.rawValue < rhs.reason.rawValue
            }
            if lhs.size.width != rhs.size.width {
                return lhs.size.width < rhs.size.width
            }
            return lhs.size.height < rhs.size.height
        }
    }

    private static func pixelFormat(for decision: RenderTextureLifecycleDecision,
                                    outputContract: RenderOutputContract,
                                    inputPixelFormat: PixelFormatContract) -> PixelFormatContract {
        switch decision.action {
        case .reuseTransient, .allocateTransient:
            return resolvedReservationPixelFormat(
                preferred: .preserveInput,
                fallback: inputPixelFormat
            )
        case .allocatePersistentOutput, .preserveForReadback:
            return resolvedReservationPixelFormat(
                preferred: outputContract.pixelFormat,
                fallback: inputPixelFormat
            )
        }
    }

    private static func resolvedReservationPixelFormat(preferred: PixelFormatContract,
                                                       fallback: PixelFormatContract) -> PixelFormatContract {
        guard preferred.preservesInput else {
            return preferred
        }
        return concreteReservationPixelFormat(from: fallback) ?? fallback
    }

    private static func concreteReservationPixelFormat(from contract: PixelFormatContract) -> PixelFormatContract? {
        guard let metalPixelFormat = contract.metalPixelFormat else {
            return nil
        }
        return PixelFormatContract(pixelFormat: metalPixelFormat, preservesInput: false)
    }

    private static func bytesPerPixel(for pixelFormat: PixelFormatContract) -> Int {
        switch pixelFormat.precision {
        case .float32:
            return 16
        case .float16:
            return 8
        case .unorm8, .preserveInput, .custom:
            if let metalPixelFormat = pixelFormat.metalPixelFormat {
                switch metalPixelFormat {
                case .r8Unorm:
                    return 1
                case .rg8Unorm:
                    return 2
                case .rgba16Float:
                    return 8
                case .rgba32Float:
                    return 16
                default:
                    return 4
                }
            }
            return 4
        }
    }

    static func optimize(graph: RenderGraph, nodeDiagnostics: [RenderNodeDiagnostic], profile: RenderProfile) -> [RenderStage] {
        guard graph.nodes.isEmpty == false else { return [] }

        var stages: [RenderStage] = []
        var currentNodeIndices: [Int] = []

        func stageKind(for kinds: [RenderNodeKind]) -> RenderStageKind {
            if kinds.contains(.boundary) {
                return .boundary
            }
            if kinds.contains(.render) {
                return .render
            }
            if kinds.contains(.blit) {
                return .blit
            }
            return .compute
        }

        func mergeClass(for node: RenderNode) -> RenderStageMergeClass? {
            guard node.breaksFusion == false, let filter = node.filter else {
                return nil
            }
            switch node.kind {
            case .compute:
                switch filter.memoryAccessPattern {
                case .point, .auto:
                    return filter.otherInputTextures.isEmpty ? .pointCompute : nil
                case .neighborhood, .dualTexture, .multiTexture:
                    return nil
                }
            case .render:
                return .renderPipeline
            case .blit:
                return .blitPass
            case .mps, .advancedMetal, .combination, .boundary:
                return nil
            }
        }

        func boundaryReason(for stageNodes: [RenderNode], diagnostics: [RenderNodeDiagnostic]) -> RenderStageBoundaryReason? {
            if stageNodes.contains(where: { $0.kind == .boundary }) {
                return .externalBoundary
            }
            if diagnostics.contains(where: \.breaksFusion) {
                return .fusionBoundary
            }
            if profile.requiresCompletedGPUWorkBeforeReadback,
               diagnostics.last?.outputSize == diagnostics.last?.outputSize {
                return .readbackReady
            }
            return nil
        }

        func flushStage() {
            guard currentNodeIndices.isEmpty == false else { return }
            let stageNodes = currentNodeIndices.map { graph.nodes[$0] }
            let diagnostics = currentNodeIndices.compactMap { index in
                nodeDiagnostics.indices.contains(index) ? nodeDiagnostics[index] : nil
            }
            let inputSize = diagnostics.first?.inputSize ?? C7Size(width: 0, height: 0)
            let outputSize = diagnostics.last?.outputSize ?? inputSize
            let kinds = stageNodes.map(\.kind)
            let mergeClasses = Set(stageNodes.compactMap(mergeClass(for:)))
            stages.append(
                RenderStage(
                    index: stages.count,
                    stageKind: stageKind(for: kinds),
                    mergeClass: mergeClasses.count == 1 ? mergeClasses.first : nil,
                    nodeIndices: currentNodeIndices,
                    kinds: kinds,
                    filterCount: stageNodes.filter { $0.filter != nil }.count,
                    breaksFusion: stageNodes.contains(where: \.breaksFusion),
                    inputSize: inputSize,
                    outputSize: outputSize,
                    boundaryReason: boundaryReason(for: stageNodes, diagnostics: diagnostics),
                    containsReadbackBoundary: profile.requiresCompletedGPUWorkBeforeReadback && currentNodeIndices.last == graph.nodes.indices.last,
                    createsDestinationTexture: stageNodes.contains(where: { $0.filter != nil }),
                    containsLocalEffectComposite: diagnostics.contains(where: { $0.name.contains("C7MaskRegionBlend") }),
                    containsTransitionKernel: diagnostics.contains(where: { $0.name.contains("Transition") }),
                    containsDerivativeResize: diagnostics.contains(where: { $0.name.contains("DerivativeResize") })
                )
            )
            currentNodeIndices.removeAll(keepingCapacity: true)
        }

        func canMerge(_ current: RenderNode, _ next: RenderNode) -> Bool {
            guard let currentClass = mergeClass(for: current),
                  let nextClass = mergeClass(for: next) else {
                return false
            }
            return currentClass == nextClass
        }

        for index in graph.nodes.indices {
            let node = graph.nodes[index]
            let previousNode = currentNodeIndices.last.flatMap { graph.nodes[$0] }
            let previousBreaksFusion = previousNode?.breaksFusion ?? false
            let kindMismatch = previousNode.map { canMerge($0, node) == false } ?? false
            let startsNewStage = currentNodeIndices.isEmpty == false && (previousBreaksFusion || node.breaksFusion || kindMismatch)
            if startsNewStage {
                flushStage()
            }

            currentNodeIndices.append(index)

            if node.breaksFusion || node.kind == .boundary {
                flushStage()
            }
        }

        flushStage()
        return stages
    }
}

private extension RenderPlanDiagnostics {
    static func makeGraphFingerprint(nodes: [RenderNodeDiagnostic],
                                     stages: [RenderStage],
                                     compilationSource: RenderCompilationSource) -> String {
        let nodePart = nodes
            .map { "\($0.index):\($0.name):\($0.kind.rawValue):\($0.outputSize.width)x\($0.outputSize.height)" }
            .joined(separator: "|")
        let stagePart = stages
            .map { stage in
                "s\(stage.index):\(stage.stageKind.rawValue):\(stage.nodeIndices.map(String.init).joined(separator: ",")):\(stage.outputSize.width)x\(stage.outputSize.height)"
            }
            .joined(separator: "|")
        return "source=\(compilationSource.rawValue)#nodes[\(nodePart)]#stages[\(stagePart)]"
    }
}

enum GraphCompiler {
    static func compile(filters: [C7FilterProtocol],
                        inputSize: C7Size,
                        profile: RenderProfile = .stablePreview,
                        derivative: ImageDerivativeSpec? = nil,
                        compilationSource: RenderCompilationSource = .filtersPrimitive,
                        outputContract: RenderOutputContract = .preserveInput,
                        imageCachePolicy: ImageCachePolicy = .transient,
                        samplerDescriptor: ImageSamplerDescriptor = .default,
                        sourceDescriptor: ImageSourceDescriptor? = nil,
                        auxiliaryInputDescriptor: ImageSourceDescriptor? = nil,
                        imageGraph: ImageGraph? = nil,
                        graphOptimizationDecisions: [String] = []) -> RenderPlan {
        var currentSize = inputSize
        var nodeDiagnostics: [RenderNodeDiagnostic] = []
        let nodes = filters.enumerated().map { index, filter -> RenderNode in
            let input = currentSize
            let outputSize = filter.resize(input: currentSize)
            let resizes = outputSize.width != currentSize.width || outputSize.height != currentSize.height
            currentSize = outputSize
            let kind = nodeKind(for: filter)
            nodeDiagnostics.append(
                RenderNodeDiagnostic(
                    index: index,
                    name: nodeName(for: filter),
                    kind: kind,
                    inputSize: input,
                    outputSize: outputSize,
                    breaksFusion: resizes || kind == .combination,
                    parameterSummary: parameterSummary(for: filter)
                )
            )
            return RenderNode(
                kind: kind,
                filter: filter,
                outputSize: outputSize,
                breaksFusion: resizes || kind == .combination
            )
        }
        let resolvedOutputContract: RenderOutputContract
        if outputContract == .preserveInput,
           let lastFilter = filters.last,
           case .render = lastFilter.modifier {
            resolvedOutputContract = lastFilter.kernelDescriptor(inputSize: currentSize).outputContract
        } else {
            resolvedOutputContract = outputContract
        }
        let resolvedDerivative = derivative ?? profile.defaultDerivativeSpec
        let derivativeOutputSize = resolvedDerivative.resolvedOutputSize(for: currentSize)
        let finalNodes: [RenderNode]
        if derivativeOutputSize != currentSize {
            nodeDiagnostics.append(
                RenderNodeDiagnostic(
                    index: nodeDiagnostics.count,
                    name: "DerivativeResize",
                    kind: .compute,
                    inputSize: currentSize,
                    outputSize: derivativeOutputSize,
                    breaksFusion: true,
                    parameterSummary: [
                        "derivative": resolvedDerivative.name,
                        "policy": resolvedDerivative.outputSizePolicy.fingerprint
                    ]
                )
            )
            finalNodes = nodes + [
                RenderNode(
                    kind: .compute,
                    filter: nil,
                    outputSize: derivativeOutputSize,
                    breaksFusion: true
                )
            ]
            currentSize = derivativeOutputSize
        } else {
            finalNodes = nodes
        }
        return RenderPlan(
            graph: RenderGraph(nodes: finalNodes),
            profile: profile,
            derivative: resolvedDerivative,
            inputSize: inputSize,
            outputSize: currentSize,
            nodeDiagnostics: nodeDiagnostics,
            compilationSource: compilationSource,
            outputContract: resolvedOutputContract,
            imageCachePolicy: imageCachePolicy,
            samplerDescriptor: samplerDescriptor,
            samplerExecutionCoverage: SamplerExecutionAdapter.coverage(
                for: filters,
                samplerDescriptor: samplerDescriptor
            ),
            sourceDescriptor: sourceDescriptor,
            auxiliaryInputDescriptor: auxiliaryInputDescriptor,
            imageGraph: imageGraph,
            graphOptimizationDecisions: graphOptimizationDecisions
        )
    }

    private static func nodeKind(for filter: C7FilterProtocol) -> RenderNodeKind {
        if filter is C7FilterPipelineProtocol { return .combination }
        if filter is LegacyCombinationFilterProtocol { return .combination }
        switch filter.modifier {
        case .compute:
            return .compute
        case .render:
            return .render
        case .blit:
            return .blit
        case .mps:
            return .mps
        case .advancedMetal:
            return .advancedMetal
        }
    }

    private static func nodeName(for filter: C7FilterProtocol) -> String {
        let typeName = String(describing: Swift.type(of: filter))
        let modifierName = filter.modifier.name
        return modifierName.isEmpty ? typeName : "\(typeName).\(modifierName)"
    }

    private static func parameterSummary(for filter: C7FilterProtocol) -> [String: String] {
        filter.parameterDescription
            .mapValues { String(describing: $0) }
            .sorted { $0.key < $1.key }
            .reduce(into: [String: String]()) { partialResult, pair in
                partialResult[pair.key] = pair.value
            }
    }
}
