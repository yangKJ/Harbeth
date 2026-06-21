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

public struct RenderStage: Sendable, Equatable {
    public let index: Int
    public let kinds: [RenderNodeKind]
    public let filterCount: Int
    public let breaksFusion: Bool

    public init(index: Int, kinds: [RenderNodeKind], filterCount: Int, breaksFusion: Bool) {
        self.index = index
        self.kinds = kinds
        self.filterCount = filterCount
        self.breaksFusion = breaksFusion
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
    public let nodes: [RenderNodeDiagnostic]
    public let stages: [RenderStage]

    public init(profile: RenderProfile,
                derivative: ImageDerivativeSpec,
                inputSize: C7Size,
                outputSize: C7Size,
                containsBoundary: Bool,
                requiresCompletedGPUWork: Bool,
                nodes: [RenderNodeDiagnostic],
                stages: [RenderStage]) {
        self.profile = profile
        self.derivative = derivative
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.containsBoundary = containsBoundary
        self.requiresCompletedGPUWork = requiresCompletedGPUWork
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
            "stages=\(stages.count)",
            "boundary=\(containsBoundary ? 1 : 0)",
            "readback=\(requiresCompletedGPUWork ? 1 : 0)",
            "plan=\(stageSummary)"
        ].joined(separator: " ")
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
                nodeDiagnostics: [RenderNodeDiagnostic]) {
        self.graph = graph
        self.profile = profile
        let requiresCompletedGPUWork = profile.requiresCompletedGPUWorkBeforeReadback
        let containsBoundary = graph.nodes.contains(where: { $0.kind == .boundary || $0.breaksFusion })
        self.requiresCompletedGPUWork = requiresCompletedGPUWork
        self.containsBoundary = containsBoundary
        self.optimizedStages = GraphOptimizer.optimize(graph: graph)
        self.diagnostics = RenderPlanDiagnostics(
            profile: profile,
            derivative: derivative,
            inputSize: inputSize,
            outputSize: outputSize,
            containsBoundary: containsBoundary,
            requiresCompletedGPUWork: requiresCompletedGPUWork,
            nodes: nodeDiagnostics,
            stages: optimizedStages
        )
    }

    public var debugSummary: String {
        diagnostics.summary
    }
}

public enum GraphOptimizer {
    public static func optimize(graph: RenderGraph) -> [RenderStage] {
        guard graph.nodes.isEmpty == false else { return [] }

        var stages: [RenderStage] = []
        var stageKinds: [RenderNodeKind] = []
        var stageFilterCount = 0
        var stageBreaksFusion = false
        var stageIndex = 0

        func flushStage() {
            guard stageKinds.isEmpty == false else { return }
            stages.append(
                RenderStage(
                    index: stageIndex,
                    kinds: stageKinds,
                    filterCount: stageFilterCount,
                    breaksFusion: stageBreaksFusion
                )
            )
            stageIndex += 1
            stageKinds.removeAll(keepingCapacity: true)
            stageFilterCount = 0
            stageBreaksFusion = false
        }

        for node in graph.nodes {
            let startsNewStage = stageKinds.isEmpty == false && (stageBreaksFusion || node.breaksFusion)
            if startsNewStage {
                flushStage()
            }

            stageKinds.append(node.kind)
            if node.filter != nil {
                stageFilterCount += 1
            }
            stageBreaksFusion = stageBreaksFusion || node.breaksFusion || node.kind == .boundary

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
                               derivative: ImageDerivativeSpec? = nil) -> RenderPlan {
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
            nodeDiagnostics: nodeDiagnostics
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
