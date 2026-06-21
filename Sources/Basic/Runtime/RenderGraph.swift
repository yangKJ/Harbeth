//
//  RenderGraph.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

public enum RenderNodeKind: String, Sendable, Equatable {
    case compute
    case render
    case blit
    case mps
    case advancedMetal
    case combination
    case boundary
}

public struct RenderNode {
    public let kind: RenderNodeKind
    public let filter: C7FilterProtocol?
    public let boundary: (RenderBoundaryAdapter)?
    public let outputSize: C7Size?
    public let breaksFusion: Bool

    public init(kind: RenderNodeKind,
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

public struct RenderGraph {
    public let nodes: [RenderNode]

    public init(nodes: [RenderNode]) {
        self.nodes = nodes
    }
}

public enum RenderStageKind: String, Sendable, Equatable {
    case compute
    case render
    case blit
    case boundary
}

public enum RenderStageBoundaryReason: String, Sendable, Equatable {
    case externalBoundary
    case fusionBoundary
    case readbackReady
}

public enum RenderCompilationSource: String, Sendable, Equatable {
    case filtersPrimitive
    case editRecipe
    case transition
    case nodeGraph
    case layerComposite
}

public enum RenderTextureLifecycleAction: String, Sendable, Equatable {
    case allocatePersistentOutput
    case allocateTransient
    case reuseTransient
    case preserveForReadback
}

public struct RenderTextureLifecycleDecision: Sendable, Equatable {
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

public struct RenderOptimizationPlan: Sendable, Equatable {
    public let intermediateTextureCount: Int
    public let reusableTextureCount: Int
    public let persistentOutputCount: Int
    public let estimatedTransientByteCount: Int
    public let estimatedPersistentByteCount: Int
    public let readbackBoundaryCount: Int
    public let formatConversionCount: Int
    public let destinationTextureCreationCount: Int
    public let lifecycleDecisions: [RenderTextureLifecycleDecision]
    public let decisions: [String]

    public init(intermediateTextureCount: Int,
                reusableTextureCount: Int,
                persistentOutputCount: Int,
                estimatedTransientByteCount: Int,
                estimatedPersistentByteCount: Int,
                readbackBoundaryCount: Int,
                formatConversionCount: Int,
                destinationTextureCreationCount: Int,
                lifecycleDecisions: [RenderTextureLifecycleDecision],
                decisions: [String]) {
        self.intermediateTextureCount = intermediateTextureCount
        self.reusableTextureCount = reusableTextureCount
        self.persistentOutputCount = persistentOutputCount
        self.estimatedTransientByteCount = estimatedTransientByteCount
        self.estimatedPersistentByteCount = estimatedPersistentByteCount
        self.readbackBoundaryCount = readbackBoundaryCount
        self.formatConversionCount = formatConversionCount
        self.destinationTextureCreationCount = destinationTextureCreationCount
        self.lifecycleDecisions = lifecycleDecisions
        self.decisions = decisions
    }
}

public struct RenderStage: Sendable, Equatable {
    public let index: Int
    public let stageKind: RenderStageKind
    public let nodeIndices: [Int]
    public let kinds: [RenderNodeKind]
    public let filterCount: Int
    public let breaksFusion: Bool
    public let inputSize: C7Size
    public let outputSize: C7Size
    public let boundaryReason: RenderStageBoundaryReason?
    public let containsReadbackBoundary: Bool
    public let createsDestinationTexture: Bool
    public let containsLocalEffectComposite: Bool
    public let containsTransitionKernel: Bool
    public let containsDerivativeResize: Bool

    public init(index: Int,
                stageKind: RenderStageKind,
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

public struct RenderNodeDiagnostic: Sendable, Equatable {
    public let index: Int
    public let name: String
    public let kind: RenderNodeKind
    public let inputSize: C7Size
    public let outputSize: C7Size
    public let breaksFusion: Bool
    public let parameterSummary: [String: String]

    public init(index: Int,
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

public struct RenderPlanDiagnostics: Sendable, Equatable {
    public let profile: RenderProfile
    public let derivative: ImageDerivativeSpec
    public let inputSize: C7Size
    public let outputSize: C7Size
    public let containsBoundary: Bool
    public let requiresCompletedGPUWork: Bool
    public let stageCount: Int
    public let compilationSource: RenderCompilationSource
    public let imageCachePolicy: ImageCachePolicy
    public let samplerDescriptor: ImageSamplerDescriptor
    public let containsLocalEffectComposite: Bool
    public let containsTransitionKernel: Bool
    public let containsDerivativeResize: Bool
    public let optimizationPlan: RenderOptimizationPlan
    public let outputContract: RenderOutputContract
    public let alphaConversionCount: Int
    public let colorConversionCount: Int
    public let pixelFormatConversionCount: Int
    public let nodes: [RenderNodeDiagnostic]
    public let stages: [RenderStage]

    public init(profile: RenderProfile,
                derivative: ImageDerivativeSpec,
                inputSize: C7Size,
                outputSize: C7Size,
                containsBoundary: Bool,
                requiresCompletedGPUWork: Bool,
                stageCount: Int,
                compilationSource: RenderCompilationSource,
                imageCachePolicy: ImageCachePolicy,
                samplerDescriptor: ImageSamplerDescriptor,
                containsLocalEffectComposite: Bool,
                containsTransitionKernel: Bool,
                containsDerivativeResize: Bool,
                optimizationPlan: RenderOptimizationPlan,
                outputContract: RenderOutputContract,
                alphaConversionCount: Int,
                colorConversionCount: Int,
                pixelFormatConversionCount: Int,
                nodes: [RenderNodeDiagnostic],
                stages: [RenderStage]) {
        self.profile = profile
        self.derivative = derivative
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.containsBoundary = containsBoundary
        self.requiresCompletedGPUWork = requiresCompletedGPUWork
        self.stageCount = stageCount
        self.compilationSource = compilationSource
        self.imageCachePolicy = imageCachePolicy
        self.samplerDescriptor = samplerDescriptor
        self.containsLocalEffectComposite = containsLocalEffectComposite
        self.containsTransitionKernel = containsTransitionKernel
        self.containsDerivativeResize = containsDerivativeResize
        self.optimizationPlan = optimizationPlan
        self.outputContract = outputContract
        self.alphaConversionCount = alphaConversionCount
        self.colorConversionCount = colorConversionCount
        self.pixelFormatConversionCount = pixelFormatConversionCount
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
            "nodes=\(nodes.count)",
            "stages=\(stageCount)",
            "boundary=\(containsBoundary ? 1 : 0)",
            "readback=\(requiresCompletedGPUWork ? 1 : 0)",
            "source=\(compilationSource.rawValue)",
            "cachePolicy=\(imageCachePolicy.rawValue)",
            "sampler=\(samplerDescriptor.fingerprint)",
            "intermediateTextures=\(optimizationPlan.intermediateTextureCount)",
            "reusableTextures=\(optimizationPlan.reusableTextureCount)",
            "transientBytes=\(optimizationPlan.estimatedTransientByteCount)",
            "lifecycle=\(optimizationPlan.lifecycleDecisions.count)",
            "formatConversions=\(optimizationPlan.formatConversionCount)",
            "alphaContract=\(outputContract.alpha)",
            "plan=\(stageSummary)"
        ].joined(separator: " ")
    }

    public func withImageCachePolicy(_ policy: ImageCachePolicy) -> RenderPlanDiagnostics {
        let plan = GraphOptimizer.makeOptimizationPlan(
            stages: stages,
            nodeDiagnostics: nodes,
            outputContract: outputContract,
            imageCachePolicy: policy
        )
        return RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            stageCount: stageCount,
            compilationSource: compilationSource,
            imageCachePolicy: policy,
            samplerDescriptor: samplerDescriptor,
            containsLocalEffectComposite: containsLocalEffectComposite,
            containsTransitionKernel: containsTransitionKernel,
            containsDerivativeResize: containsDerivativeResize,
            optimizationPlan: plan,
            outputContract: outputContract,
            alphaConversionCount: alphaConversionCount,
            colorConversionCount: colorConversionCount,
            pixelFormatConversionCount: pixelFormatConversionCount,
            nodes: nodes,
            stages: stages
        )
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> RenderPlanDiagnostics {
        RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            stageCount: stageCount,
            compilationSource: compilationSource,
            imageCachePolicy: imageCachePolicy,
            samplerDescriptor: descriptor,
            containsLocalEffectComposite: containsLocalEffectComposite,
            containsTransitionKernel: containsTransitionKernel,
            containsDerivativeResize: containsDerivativeResize,
            optimizationPlan: optimizationPlan,
            outputContract: outputContract,
            alphaConversionCount: alphaConversionCount,
            colorConversionCount: colorConversionCount,
            pixelFormatConversionCount: pixelFormatConversionCount,
            nodes: nodes,
            stages: stages
        )
    }
}

public struct RenderPlan {
    public let graph: RenderGraph
    public let profile: RenderProfile
    public let requiresCompletedGPUWork: Bool
    public let containsBoundary: Bool
    public let optimizedStages: [RenderStage]
    public let diagnostics: RenderPlanDiagnostics

    public init(graph: RenderGraph,
                profile: RenderProfile,
                derivative: ImageDerivativeSpec,
                inputSize: C7Size,
                outputSize: C7Size,
                nodeDiagnostics: [RenderNodeDiagnostic],
                compilationSource: RenderCompilationSource,
                outputContract: RenderOutputContract = .preserveInput,
                imageCachePolicy: ImageCachePolicy = .transient,
                samplerDescriptor: ImageSamplerDescriptor = .default) {
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
        let optimizationPlan = GraphOptimizer.makeOptimizationPlan(
            stages: optimizedStages,
            nodeDiagnostics: nodeDiagnostics,
            outputContract: outputContract,
            imageCachePolicy: imageCachePolicy
        )
        self.diagnostics = RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            stageCount: optimizedStages.count,
            compilationSource: compilationSource,
            imageCachePolicy: imageCachePolicy,
            samplerDescriptor: samplerDescriptor,
            containsLocalEffectComposite: optimizedStages.contains(where: \.containsLocalEffectComposite),
            containsTransitionKernel: optimizedStages.contains(where: \.containsTransitionKernel),
            containsDerivativeResize: optimizedStages.contains(where: \.containsDerivativeResize),
            optimizationPlan: optimizationPlan,
            outputContract: outputContract,
            alphaConversionCount: outputContract.requiresAlphaConversion ? 1 : 0,
            colorConversionCount: outputContract.requiresColorSpaceConversion ? 1 : 0,
            pixelFormatConversionCount: outputContract.requiresPixelFormatConversion ? max(optimizationPlan.formatConversionCount, 1) : optimizationPlan.formatConversionCount,
            nodes: nodeDiagnostics,
            stages: optimizedStages
        )
    }

    public var debugSummary: String {
        diagnostics.summary
    }
}

public enum GraphOptimizer {
    public static func makeOptimizationPlan(stages: [RenderStage],
                                            nodeDiagnostics: [RenderNodeDiagnostic],
                                            outputContract: RenderOutputContract = .preserveInput,
                                            imageCachePolicy: ImageCachePolicy = .transient) -> RenderOptimizationPlan {
        let intermediateTextureCount = max(nodeDiagnostics.count - 1, 0)
        let readbackBoundaryCount = stages.filter(\.containsReadbackBoundary).count
        let destinationTextureCreationCount = stages.filter(\.createsDestinationTexture).count
        let formatConversionCount = outputContract.requiresPixelFormatConversion ? 1 : 0
        let lifecycleDecisions = makeLifecycleDecisions(stages: stages)
        let reusableTextureCount = lifecycleDecisions.filter { $0.action == .reuseTransient }.count
        let estimatedTransientByteCount = lifecycleDecisions
            .filter { $0.action == .reuseTransient || $0.action == .allocateTransient }
            .reduce(0) { $0 + estimatedByteCount(for: $1.size) }
        let estimatedPersistentByteCount = lifecycleDecisions
            .filter { $0.action == .allocatePersistentOutput || $0.action == .preserveForReadback }
            .reduce(0) { $0 + estimatedByteCount(for: $1.size) }
        var decisions: [String] = []
        if intermediateTextureCount > 0 {
            decisions.append("reuseTransientIntermediateTextures")
        }
        if reusableTextureCount > 0 {
            decisions.append("planTransientTextureReuse")
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
        if decisions.isEmpty {
            decisions.append("singleStageNoOptimizationNeeded")
        }
        return RenderOptimizationPlan(
            intermediateTextureCount: intermediateTextureCount,
            reusableTextureCount: reusableTextureCount,
            persistentOutputCount: 1,
            estimatedTransientByteCount: estimatedTransientByteCount,
            estimatedPersistentByteCount: estimatedPersistentByteCount,
            readbackBoundaryCount: readbackBoundaryCount,
            formatConversionCount: formatConversionCount,
            destinationTextureCreationCount: destinationTextureCreationCount,
            lifecycleDecisions: lifecycleDecisions,
            decisions: decisions
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

    private static func estimatedByteCount(for size: C7Size) -> Int {
        max(size.width, 0) * max(size.height, 0) * 4
    }

    public static func optimize(graph: RenderGraph, nodeDiagnostics: [RenderNodeDiagnostic], profile: RenderProfile) -> [RenderStage] {
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
            stages.append(
                RenderStage(
                    index: stages.count,
                    stageKind: stageKind(for: kinds),
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

        for index in graph.nodes.indices {
            let node = graph.nodes[index]
            let previousBreaksFusion = currentNodeIndices.last.flatMap { graph.nodes[$0].breaksFusion } ?? false
            let startsNewStage = currentNodeIndices.isEmpty == false && (previousBreaksFusion || node.breaksFusion)
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

public enum GraphCompiler {
    public static func compile(filters: [C7FilterProtocol],
                               inputSize: C7Size,
                               profile: RenderProfile = .stablePreview,
                               derivative: ImageDerivativeSpec? = nil,
                               compilationSource: RenderCompilationSource = .filtersPrimitive,
                               outputContract: RenderOutputContract = .preserveInput,
                               imageCachePolicy: ImageCachePolicy = .transient,
                               samplerDescriptor: ImageSamplerDescriptor = .default) -> RenderPlan {
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
            outputContract: outputContract,
            imageCachePolicy: imageCachePolicy,
            samplerDescriptor: samplerDescriptor
        )
    }

    private static func nodeKind(for filter: C7FilterProtocol) -> RenderNodeKind {
        if filter is C7CombinationBase { return .combination }
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
