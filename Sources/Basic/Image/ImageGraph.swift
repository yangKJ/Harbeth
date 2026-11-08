//
//  ImageGraph.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct ImageGraphNodeID: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func < (lhs: ImageGraphNodeID, rhs: ImageGraphNodeID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ImageGraphNodeKind: String, Sendable, Equatable, Hashable {
    case source
    case filters
    case kernel
    case recipe
    case transition
    case layerComposite
    case cachePolicy
    case samplerDescriptor
    case derivativeResize
}

public struct ImageGraphEdge: Sendable, Equatable, Hashable {
    public let from: ImageGraphNodeID
    public let to: ImageGraphNodeID
    public let label: String

    init(from: ImageGraphNodeID, to: ImageGraphNodeID, label: String = "image") {
        self.from = from
        self.to = to
        self.label = label
    }
}

public struct ImageGraphNode: Sendable, Equatable, Hashable {
    public let id: ImageGraphNodeID
    public let kind: ImageGraphNodeKind
    public let name: String
    public let cachePolicy: ImageCachePolicy
    public let samplerDescriptor: ImageSamplerDescriptor
    public let sourceKind: String?
    public let filterCount: Int
    public var fingerprint: String { fingerprintText.value }
    let fingerprintText: ImageGraphFingerprint

    init(id: ImageGraphNodeID,
         kind: ImageGraphNodeKind,
         name: String,
         cachePolicy: ImageCachePolicy,
         samplerDescriptor: ImageSamplerDescriptor,
         sourceKind: String? = nil,
         filterCount: Int = 0,
         fingerprint: String) {
        self.id = id
        self.kind = kind
        self.name = name
        self.cachePolicy = cachePolicy
        self.samplerDescriptor = samplerDescriptor
        self.sourceKind = sourceKind
        self.filterCount = filterCount
        self.fingerprintText = ImageGraphFingerprint(fingerprint)
    }

    init(id: ImageGraphNodeID,
         kind: ImageGraphNodeKind,
         name: String,
         cachePolicy: ImageCachePolicy,
         samplerDescriptor: ImageSamplerDescriptor,
         sourceKind: String?,
         filterCount: Int,
         fingerprintText: ImageGraphFingerprint) {
        self.id = id
        self.kind = kind
        self.name = name
        self.cachePolicy = cachePolicy
        self.samplerDescriptor = samplerDescriptor
        self.sourceKind = sourceKind
        self.filterCount = filterCount
        self.fingerprintText = fingerprintText
    }

    public var formsBoundary: Bool {
        switch kind {
        case .source, .recipe, .transition, .layerComposite, .derivativeResize:
            return true
        case .filters, .kernel, .cachePolicy, .samplerDescriptor:
            return cachePolicy == .persistent
        }
    }
}

public struct ImageGraph: Sendable, Equatable, Hashable {
    public let nodes: [ImageGraphNode]
    public let edges: [ImageGraphEdge]
    public let rootNodeID: ImageGraphNodeID
    public let profile: RenderProfile
    public let derivative: ImageDerivativeSpec

    init(nodes: [ImageGraphNode], edges: [ImageGraphEdge], rootNodeID: ImageGraphNodeID, profile: RenderProfile, derivative: ImageDerivativeSpec) {
        self.nodes = nodes.sorted { $0.id < $1.id }
        self.edges = edges.sorted {
            if $0.from != $1.from {
                return $0.from < $1.from
            }
            if $0.to != $1.to {
                return $0.to < $1.to
            }
            return $0.label < $1.label
        }
        self.rootNodeID = rootNodeID
        self.profile = profile
        self.derivative = derivative
    }

    public var nodeCount: Int {
        nodes.count
    }

    public var edgeCount: Int {
        edges.count
    }

    public var persistentBoundaryCount: Int {
        nodes.reduce(0) { $0 + ($1.cachePolicy == .persistent || $1.formsBoundary ? 1 : 0) }
    }

    public var transientReuseCandidateCount: Int {
        nodes.reduce(0) { count, node in
            count + (node.cachePolicy == .transient && (node.kind == .filters || node.kind == .kernel) ? 1 : 0)
        }
    }

    public var sharedDependencyNodeCount: Int {
        let outgoingCounts = edges.reduce(into: [ImageGraphNodeID: Int]()) { counts, edge in
            counts[edge.from, default: 0] += 1
        }
        return nodes.reduce(0) { $0 + (outgoingCounts[$1.id, default: 0] > 1 ? 1 : 0) }
    }

    public func outgoingEdgeCount(for nodeID: ImageGraphNodeID) -> Int {
        edges.reduce(0) { $0 + ($1.from == nodeID ? 1 : 0) }
    }

    public var fingerprint: String {
        let nodePart = nodes
            .map { "\($0.id.rawValue):\($0.kind.rawValue):\($0.fingerprint)" }
            .joined(separator: "|")
        let edgePart = edges
            .map { "\($0.from.rawValue)>\($0.to.rawValue):\($0.label)" }
            .joined(separator: "|")
        return [
            "profile=\(String(describing: profile))",
            "derivative=\(derivative.name)",
            "root=\(rootNodeID.rawValue)",
            "nodes=\(nodePart)",
            "edges=\(edgePart)"
        ].joined(separator: "#")
    }
}

struct ImageGraphOptimizationResult: Sendable, Equatable, Hashable {
    let graph: ImageGraph
    let decisions: [String]

    init(graph: ImageGraph, decisions: [String]) {
        self.graph = graph
        self.decisions = decisions
    }
}

enum ImageGraphOptimizer {
    static func optimize(_ graph: ImageGraph) -> ImageGraphOptimizationResult {
        guard graph.nodes.isEmpty == false else {
            return ImageGraphOptimizationResult(graph: graph, decisions: ["emptyGraph"])
        }

        var nodes = graph.nodes
        var edges = graph.edges
        var rootNodeID = graph.rootNodeID
        var decisions: [String] = []
        var nodesByID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var firstInputByNode: [ImageGraphNodeID: ImageGraphNodeID] = [:]
        var outgoingCounts: [ImageGraphNodeID: Int] = [:]

        func indexEdge(_ edge: ImageGraphEdge) {
            if firstInputByNode[edge.to] == nil { firstInputByNode[edge.to] = edge.from }
            outgoingCounts[edge.from, default: 0] += 1
        }
        edges.forEach(indexEdge)

        func rewriteEdges(_ transform: (ImageGraphEdge) -> ImageGraphEdge?) {
            firstInputByNode.removeAll(keepingCapacity: true)
            outgoingCounts.removeAll(keepingCapacity: true)
            // 重接时同步重建索引，保留当前边顺序与重复计数，不另做全图扫描。
            edges = edges.compactMap { edge in
                guard let rewritten = transform(edge) else { return nil }
                indexEdge(rewritten)
                return rewritten
            }
        }

        func mergeDecision(for node: ImageGraphNode) -> String? {
            switch node.kind {
            case .filters:
                return "mergeAdjacentFilterNodes"
            case .kernel:
                return "mergeAdjacentKernelNodes"
            default:
                return nil
            }
        }

        func isTransparentWrapper(_ node: ImageGraphNode, inputNode: ImageGraphNode) -> String? {
            switch node.kind {
            case .cachePolicy:
                return node.cachePolicy == inputNode.cachePolicy ? "collapseRedundantCachePolicyWrapper" : nil
            case .samplerDescriptor:
                return node.samplerDescriptor == inputNode.samplerDescriptor ? "collapseRedundantSamplerWrapper" : nil
            default:
                return nil
            }
        }

        var changed = true
        while changed {
            changed = false
            for current in nodes.sorted(by: { $0.id < $1.id }) {
                let inputNode = firstInputByNode[current.id].flatMap { nodesByID[$0] }
                if let inputNode,
                   let decision = isTransparentWrapper(current, inputNode: inputNode) {
                    nodes.removeAll(where: { $0.id == current.id })
                    nodesByID.removeValue(forKey: current.id)
                    rewriteEdges { edge in
                        if edge.from == inputNode.id && edge.to == current.id {
                            return nil
                        }
                        if edge.to == current.id {
                            return ImageGraphEdge(from: edge.from, to: inputNode.id, label: edge.label)
                        }
                        if edge.from == current.id {
                            return ImageGraphEdge(from: inputNode.id, to: edge.to, label: edge.label)
                        }
                        return edge
                    }
                    if rootNodeID == current.id {
                        rootNodeID = inputNode.id
                    }
                    decisions.append(decision)
                    changed = true
                    break
                }

                guard let mergeDecision = mergeDecision(for: current),
                      current.cachePolicy == .transient,
                      let inputNode,
                      inputNode.kind == current.kind,
                      inputNode.cachePolicy == .transient,
                      inputNode.formsBoundary == false,
                      current.formsBoundary == false else {
                    continue
                }

                guard outgoingCounts[inputNode.id, default: 0] == 1 else {
                    if decisions.contains("preserveSharedInputDependency") == false {
                        decisions.append("preserveSharedInputDependency")
                    }
                    continue
                }

                guard inputNode.samplerDescriptor == current.samplerDescriptor else {
                    if decisions.contains("preserveSamplerBoundary") == false {
                        decisions.append("preserveSamplerBoundary")
                    }
                    continue
                }

                let merged = ImageGraphNode(
                    id: current.id,
                    kind: current.kind,
                    name: "\(inputNode.name)+\(current.name)",
                    cachePolicy: .transient,
                    samplerDescriptor: current.samplerDescriptor,
                    sourceKind: current.sourceKind ?? inputNode.sourceKind,
                    filterCount: inputNode.filterCount + current.filterCount,
                    fingerprintText: ImageGraphFingerprint(parts: [inputNode.fingerprintText, ImageGraphFingerprint("||"), current.fingerprintText])
                )
                nodes.removeAll(where: { $0.id == inputNode.id || $0.id == current.id })
                nodes.append(merged)
                nodesByID.removeValue(forKey: inputNode.id)
                nodesByID[current.id] = merged
                rewriteEdges { edge in
                    if edge.from == inputNode.id && edge.to == current.id {
                        return nil
                    }
                    if edge.to == inputNode.id {
                        return ImageGraphEdge(from: edge.from, to: current.id, label: edge.label)
                    }
                    if edge.from == inputNode.id {
                        return ImageGraphEdge(from: current.id, to: edge.to, label: edge.label)
                    }
                    return edge
                }
                decisions.append(mergeDecision)
                changed = true
                break
            }
        }

        if decisions.isEmpty {
            decisions.append("preserveDeclaredGraph")
        }

        let optimized = ImageGraph(
            nodes: nodes,
            edges: deduplicated(edges),
            rootNodeID: rootNodeID,
            profile: graph.profile,
            derivative: graph.derivative
        )
        return ImageGraphOptimizationResult(graph: optimized, decisions: decisions)
    }

    private static func deduplicated(_ edges: [ImageGraphEdge]) -> [ImageGraphEdge] {
        var seen = Set<ImageGraphEdge>()
        return edges.filter { seen.insert($0).inserted }
    }
}
