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
        public let stageCount: Int
        public let compilationSource: String
        public let inputSize: String
        public let outputSize: String

        public init(diagnostics: RenderPlanDiagnostics) {
            self.summary = diagnostics.summary
            self.profile = String(describing: diagnostics.profile)
            self.derivative = diagnostics.derivative.name
            self.graphFingerprint = diagnostics.graphFingerprint
            self.graphNodeCount = diagnostics.graphNodeCount
            self.graphEdgeCount = diagnostics.graphEdgeCount
            self.optimizedGraphNodeCount = diagnostics.optimizedGraphNodeCount
            self.graphOptimizationDecisions = diagnostics.graphOptimizationDecisions
            self.persistentBoundaryCount = diagnostics.persistentBoundaryCount
            self.transientReuseCandidateCount = diagnostics.transientReuseCandidateCount
            self.stageCount = diagnostics.stageCount
            self.compilationSource = diagnostics.compilationSource.rawValue
            self.inputSize = "\(diagnostics.inputSize.width)x\(diagnostics.inputSize.height)"
            self.outputSize = "\(diagnostics.outputSize.width)x\(diagnostics.outputSize.height)"
        }
    }

    public struct Node: Sendable, Codable, Equatable, Hashable {
        public let id: Int
        public let kind: String
        public let name: String
        public let cachePolicy: String
        public let filterCount: Int
        public let sourceKind: String?

        public init(id: Int,
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

        public init(from: Int, to: Int, label: String) {
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

    public init(summary: String,
                diagnostics: Diagnostics,
                nodes: [Node],
                edges: [Edge],
                optimizationDecisions: [String],
                dotGraph: String) {
        self.summary = summary
        self.diagnostics = diagnostics
        self.nodes = nodes
        self.edges = edges
        self.optimizationDecisions = optimizationDecisions
        self.dotGraph = dotGraph
    }

    public init(graph: ImageGraph,
                diagnostics: RenderPlanDiagnostics,
                optimizationDecisions: [String]) {
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
            dotGraph: RenderGraphDebugSnapshot.makeDOTGraph(nodes: nodes, edges: edges)
        )
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
