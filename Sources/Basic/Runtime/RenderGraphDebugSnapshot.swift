//
//  RenderGraphDebugSnapshot.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct RenderGraphDebugSnapshot: Sendable, Codable, Equatable, Hashable {
    public struct Diagnostics: Sendable, Codable, Equatable, Hashable {
        public let summary: String
        public let profile: String
        public let derivative: String
        public let graphFingerprint: String
        public let graphNodeCount: Int
        public let graphEdgeCount: Int
        public let optimizedGraphNodeCount: Int
        public let graphOptimizationDecisions: [String]
        public let persistentBoundaryCount: Int
        public let transientReuseCandidateCount: Int
        public let sharedDependencyNodeCount: Int
        public let inputDirectPlaneBridgeCount: Int
        public let inputBridgePolicy: String?
        public let inputYCbCrDecode: String?
        public let frameHostSource: String?
        public let frameHostDecision: String
        public let frameHostTimingPolicy: String
        public let frameHostRealtimePreviewEligible: Bool
        public let frameHostSupportsVisibilityPause: Bool
        public let frameHostRequiresPlaneAwareDecode: Bool
        public let frameHostMetadataCompleteness: String
        public let resolvedPreviewHostStrategy: String
        public let sampleBufferHostEligible: Bool
        public let sampleBufferHostPayloadAvailable: Bool
        public let sampleBufferHostRequiresRematerialization: Bool
        public let hostRecoveryPolicy: String
        public let hostRecoveredByFlush: Bool
        public let hostFellBackToMetal: Bool
        public let inputPixelPrecision: String
        public let inputHDRFriendly: Bool
        public let outputAttachmentLabels: [String]
        public let outputAttachmentDebugViews: [String]
        public let outputAttachmentReadbackPixelFormats: [String]
        public let outputAttachmentMonochromePreviewFlags: [Bool]
        public let optimizationPlan: RenderOptimizationPlan
        public let allocationStrategy: String
        public let requestedAllocationStrategy: String?
        public let allocationFallbackReason: String?
        public let textureRequestCount: Int
        public let textureReuseHitCount: Int
        public let textureReuseHitRatio: Double
        public let heapBackedAllocationCount: Int
        public let allocatorDecisions: [String]
        public let stageCount: Int
        public let compilationSource: String
        public let inputSize: String
        public let outputSize: String

        init(summary: String,
             profile: String,
             derivative: String,
             graphFingerprint: String,
             graphNodeCount: Int,
             graphEdgeCount: Int,
             optimizedGraphNodeCount: Int,
             graphOptimizationDecisions: [String],
             persistentBoundaryCount: Int,
             transientReuseCandidateCount: Int,
             sharedDependencyNodeCount: Int,
             inputDirectPlaneBridgeCount: Int,
             inputBridgePolicy: String? = nil,
             inputYCbCrDecode: String? = nil,
             frameHostSource: String? = nil,
             frameHostDecision: String = PreviewHostRenderingDecision.directTexturePassthrough.rawValue,
             frameHostTimingPolicy: String = PreviewHostTimingPolicy.displayStable.rawValue,
             frameHostRealtimePreviewEligible: Bool = false,
             frameHostSupportsVisibilityPause: Bool = false,
             frameHostRequiresPlaneAwareDecode: Bool = false,
             frameHostMetadataCompleteness: String = FrameHostMetadataCompleteness(
                hasFrameSize: false,
                hasOrientation: false,
                hasMirror: false,
                hasDeviceOrientation: false,
                hasTiming: false,
                hasSampleAttachments: false
             ).fingerprint,
             resolvedPreviewHostStrategy: String = PreviewHostStrategy.metalTextureHost.rawValue,
             sampleBufferHostEligible: Bool = false,
             sampleBufferHostPayloadAvailable: Bool = false,
             sampleBufferHostRequiresRematerialization: Bool = false,
             hostRecoveryPolicy: String = PreviewHostRecoveryPolicy.flushThenFallbackToMetal.rawValue,
             hostRecoveredByFlush: Bool = false,
             hostFellBackToMetal: Bool = false,
             inputPixelPrecision: String,
             inputHDRFriendly: Bool,
             outputAttachmentLabels: [String],
             outputAttachmentDebugViews: [String],
             outputAttachmentReadbackPixelFormats: [String],
             outputAttachmentMonochromePreviewFlags: [Bool],
             optimizationPlan: RenderOptimizationPlan,
             allocationStrategy: String,
             requestedAllocationStrategy: String? = nil,
             allocationFallbackReason: String? = nil,
             textureRequestCount: Int,
             textureReuseHitCount: Int,
             textureReuseHitRatio: Double,
             heapBackedAllocationCount: Int,
             allocatorDecisions: [String],
             stageCount: Int,
             compilationSource: String,
             inputSize: String,
             outputSize: String) {
            self.summary = summary
            self.profile = profile
            self.derivative = derivative
            self.graphFingerprint = graphFingerprint
            self.graphNodeCount = graphNodeCount
            self.graphEdgeCount = graphEdgeCount
            self.optimizedGraphNodeCount = optimizedGraphNodeCount
            self.graphOptimizationDecisions = graphOptimizationDecisions
            self.persistentBoundaryCount = persistentBoundaryCount
            self.transientReuseCandidateCount = transientReuseCandidateCount
            self.sharedDependencyNodeCount = sharedDependencyNodeCount
            self.inputDirectPlaneBridgeCount = inputDirectPlaneBridgeCount
            self.inputBridgePolicy = inputBridgePolicy
            self.inputYCbCrDecode = inputYCbCrDecode
            self.frameHostSource = frameHostSource
            self.frameHostDecision = frameHostDecision
            self.frameHostTimingPolicy = frameHostTimingPolicy
            self.frameHostRealtimePreviewEligible = frameHostRealtimePreviewEligible
            self.frameHostSupportsVisibilityPause = frameHostSupportsVisibilityPause
            self.frameHostRequiresPlaneAwareDecode = frameHostRequiresPlaneAwareDecode
            self.frameHostMetadataCompleteness = frameHostMetadataCompleteness
            self.resolvedPreviewHostStrategy = resolvedPreviewHostStrategy
            self.sampleBufferHostEligible = sampleBufferHostEligible
            self.sampleBufferHostPayloadAvailable = sampleBufferHostPayloadAvailable
            self.sampleBufferHostRequiresRematerialization = sampleBufferHostRequiresRematerialization
            self.hostRecoveryPolicy = hostRecoveryPolicy
            self.hostRecoveredByFlush = hostRecoveredByFlush
            self.hostFellBackToMetal = hostFellBackToMetal
            self.inputPixelPrecision = inputPixelPrecision
            self.inputHDRFriendly = inputHDRFriendly
            self.outputAttachmentLabels = outputAttachmentLabels
            self.outputAttachmentDebugViews = outputAttachmentDebugViews
            self.outputAttachmentReadbackPixelFormats = outputAttachmentReadbackPixelFormats
            self.outputAttachmentMonochromePreviewFlags = outputAttachmentMonochromePreviewFlags
            self.optimizationPlan = optimizationPlan
            self.allocationStrategy = allocationStrategy
            self.requestedAllocationStrategy = requestedAllocationStrategy
            self.allocationFallbackReason = allocationFallbackReason
            self.textureRequestCount = textureRequestCount
            self.textureReuseHitCount = textureReuseHitCount
            self.textureReuseHitRatio = textureReuseHitRatio
            self.heapBackedAllocationCount = heapBackedAllocationCount
            self.allocatorDecisions = allocatorDecisions
            self.stageCount = stageCount
            self.compilationSource = compilationSource
            self.inputSize = inputSize
            self.outputSize = outputSize
        }

        init(diagnostics: RenderPlanDiagnostics) {
            let frameHostHint = diagnostics.frameHostRuntimeHint
            self.init(
                summary: diagnostics.summary,
                profile: String(describing: diagnostics.profile),
                derivative: diagnostics.derivative.name,
                graphFingerprint: diagnostics.graphFingerprint,
                graphNodeCount: diagnostics.graphNodeCount,
                graphEdgeCount: diagnostics.graphEdgeCount,
                optimizedGraphNodeCount: diagnostics.optimizedGraphNodeCount,
                graphOptimizationDecisions: diagnostics.graphOptimizationDecisions,
                persistentBoundaryCount: diagnostics.persistentBoundaryCount,
                transientReuseCandidateCount: diagnostics.transientReuseCandidateCount,
                sharedDependencyNodeCount: diagnostics.sharedDependencyNodeCount,
                inputDirectPlaneBridgeCount: diagnostics.inputDirectPlaneBridgeCount,
                inputBridgePolicy: diagnostics.inputBridgePolicy?.rawValue,
                inputYCbCrDecode: diagnostics.inputYCbCrDecodeContract?.fingerprint,
                frameHostSource: diagnostics.frameHostSourceDescriptor?.fingerprint,
                frameHostDecision: frameHostHint.decision.rawValue,
                frameHostTimingPolicy: frameHostHint.timingPolicy.rawValue,
                frameHostRealtimePreviewEligible: frameHostHint.isRealtimePreviewEligible,
                frameHostSupportsVisibilityPause: frameHostHint.supportsVisibilityPause,
                frameHostRequiresPlaneAwareDecode: frameHostHint.requiresPlaneAwareDecode,
                frameHostMetadataCompleteness: frameHostHint.metadataCompleteness.fingerprint,
                resolvedPreviewHostStrategy: diagnostics.resolvedPreviewHostStrategy,
                sampleBufferHostEligible: diagnostics.sampleBufferHostEligible,
                sampleBufferHostPayloadAvailable: diagnostics.sampleBufferHostPayloadAvailable,
                sampleBufferHostRequiresRematerialization: diagnostics.sampleBufferHostRequiresRematerialization,
                hostRecoveryPolicy: diagnostics.hostRecoveryPolicy,
                hostRecoveredByFlush: diagnostics.hostRecoveredByFlush,
                hostFellBackToMetal: diagnostics.hostFellBackToMetal,
                inputPixelPrecision: diagnostics.inputPixelPrecision.rawValue,
                inputHDRFriendly: diagnostics.inputIsHDRFriendly,
                outputAttachmentLabels: diagnostics.outputContract.attachmentDebugPolicies.map(\.label),
                outputAttachmentDebugViews: diagnostics.outputContract.attachmentDebugPolicies.map { $0.interpretation.rawValue },
                outputAttachmentReadbackPixelFormats: diagnostics.outputContract.attachmentDebugPolicies.map { $0.preferredReadbackPixelFormat.name },
                outputAttachmentMonochromePreviewFlags: diagnostics.outputContract.attachmentDebugPolicies.map(\.prefersMonochromePreview),
                optimizationPlan: diagnostics.optimizationPlan,
                allocationStrategy: diagnostics.optimizationPlan.allocationStrategy.rawValue,
                requestedAllocationStrategy: diagnostics.optimizationPlan.requestedAllocationStrategy?.rawValue,
                allocationFallbackReason: diagnostics.optimizationPlan.allocationFallbackReason,
                textureRequestCount: diagnostics.optimizationPlan.textureRequestCount,
                textureReuseHitCount: diagnostics.optimizationPlan.textureReuseHitCount,
                textureReuseHitRatio: diagnostics.optimizationPlan.textureReuseHitRatio,
                heapBackedAllocationCount: diagnostics.optimizationPlan.heapBackedAllocationCount,
                allocatorDecisions: diagnostics.optimizationPlan.allocatorDecisions,
                stageCount: diagnostics.stageCount,
                compilationSource: diagnostics.compilationSource.rawValue,
                inputSize: "\(diagnostics.inputSize.width)x\(diagnostics.inputSize.height)",
                outputSize: "\(diagnostics.outputSize.width)x\(diagnostics.outputSize.height)"
            )
        }
    }

    public struct Node: Sendable, Codable, Equatable, Hashable {
        public let id: Int
        public let kind: String
        public let name: String
        public let cachePolicy: String
        public let filterCount: Int
        public let sourceKind: String?

        init(id: Int,
             kind: String,
             name: String,
             cachePolicy: String,
             filterCount: Int,
             sourceKind: String?) {
            self.id = id
            self.kind = kind
            self.name = name
            self.cachePolicy = cachePolicy
            self.filterCount = filterCount
            self.sourceKind = sourceKind
        }
    }

    public struct Edge: Sendable, Codable, Equatable, Hashable {
        public let from: Int
        public let to: Int
        public let label: String

        init(from: Int, to: Int, label: String) {
            self.from = from
            self.to = to
            self.label = label
        }
    }

    public let summary: String
    public let diagnostics: Diagnostics
    public let nodes: [Node]
    public let edges: [Edge]
    public let optimizationDecisions: [String]
    public let dotGraph: String
    let renderRecipe: RenderRecipe?

    init(summary: String,
         diagnostics: Diagnostics,
         nodes: [Node],
         edges: [Edge],
         optimizationDecisions: [String],
         dotGraph: String,
         renderRecipe: RenderRecipe? = nil) {
        self.summary = summary
        self.diagnostics = diagnostics
        self.nodes = nodes
        self.edges = edges
        self.optimizationDecisions = optimizationDecisions
        self.dotGraph = dotGraph
        self.renderRecipe = renderRecipe
    }

    init(graph: ImageGraph,
         diagnostics: RenderPlanDiagnostics,
         optimizationDecisions: [String],
         renderRecipe: RenderRecipe? = nil) {
        let nodes = graph.nodes.map {
            Node(
                id: $0.id.rawValue,
                kind: $0.kind.rawValue,
                name: $0.name,
                cachePolicy: $0.cachePolicy.rawValue,
                filterCount: $0.filterCount,
                sourceKind: $0.sourceKind
            )
        }
        let edges = graph.edges.map { Edge(from: $0.from.rawValue, to: $0.to.rawValue, label: $0.label) }
        self.init(
            summary: diagnostics.summary,
            diagnostics: Diagnostics(diagnostics: diagnostics),
            nodes: nodes,
            edges: edges,
            optimizationDecisions: optimizationDecisions,
            dotGraph: RenderGraphDebugSnapshot.makeDOTGraph(nodes: nodes, edges: edges),
            renderRecipe: renderRecipe
        )
    }

    public func jsonData(prettyPrinted: Bool = false, sortedKeys: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting.insert(.prettyPrinted)
        }
        if sortedKeys {
            encoder.outputFormatting.insert(.sortedKeys)
        }
        return try encoder.encode(self)
    }

    public func jsonString(prettyPrinted: Bool = false, sortedKeys: Bool = true) throws -> String {
        let data = try jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HarbethError.configurationInvalid("RenderGraphDebugSnapshot JSON encoding is not valid UTF-8.")
        }
        return string
    }

    private static func makeDOTGraph(nodes: [Node], edges: [Edge]) -> String {
        let nodeLines = nodes.map { node in
            let label = [
                "\(node.name)",
                "kind=\(node.kind)",
                "cache=\(node.cachePolicy)",
                "filters=\(node.filterCount)",
                node.sourceKind.map { "source=\($0)" } ?? nil
            ]
            .compactMap { $0 }
            .joined(separator: "\\n")
            return "  n\(node.id) [label=\"\(label)\"];"
        }
        let edgeLines = edges.map { edge in
            "  n\(edge.from) -> n\(edge.to) [label=\"\(edge.label)\"];"
        }
        return (["digraph ImageGraph {"] + nodeLines + edgeLines + ["}"]).joined(separator: "\n")
    }
}
