//
//  ImageGraphBuilder.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation

final class ImageGraphBuilder {
    private let profile: RenderProfile
    private let derivative: ImageDerivativeSpec
    private var nodes: [ImageGraphNode] = []
    private var edges: [ImageGraphEdge] = []
    private var nextID: Int = 0

    init(profile: RenderProfile, derivative: ImageDerivativeSpec) {
        self.profile = profile
        self.derivative = derivative
    }

    func build(from node: ImageNode) throws -> ImageGraph {
        let rootNodeID = try append(node)
        return ImageGraph(
            nodes: nodes,
            edges: edges,
            rootNodeID: rootNodeID,
            profile: profile,
            derivative: derivative
        )
    }

    private func append(_ node: ImageNode) throws -> ImageGraphNodeID {
        switch node.storage {
        case .source(let source):
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .source,
                    name: "Source.\(source.kindName)",
                    cachePolicy: source.cachePolicy,
                    samplerDescriptor: .default,
                    sourceKind: source.kindName,
                    filterCount: 0,
                    fingerprint: source.descriptor.fingerprint
                )
            )
            return nodeID
        case .filters:
            return try appendFilterNodes(node)
        case .kernel(let input, let descriptor, _):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .kernel,
                    name: descriptor.filterName,
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: 1,
                    fingerprint: descriptor.fingerprint
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        case .edit(let input, let recipe, let mode):
            let inputID = try append(input)
            let nodeID = allocateID()
            let planning = recipe.planningDescriptor(for: mode)
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .recipe,
                    name: "EditRecipe.\(mode.rawValue)",
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: planning.filterCount,
                    fingerprint: [
                        "input=\(input.resolutionFingerprint(profile: profile, derivative: derivative))",
                        planning.fingerprint
                    ].joined(separator: "|")
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        case .transition(let recipe):
            let fromID = try append(ImageNode.source(recipe.from))
            let toID = try append(ImageNode.source(recipe.to))
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .transition,
                    name: String(describing: type(of: recipe.kernel)),
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: recipe.from.kindName,
                    filterCount: 1,
                    fingerprint: [
                        recipe.from.resolutionFingerprint,
                        recipe.to.resolutionFingerprint,
                        recipe.kernel.fingerprint,
                        "progress=\(recipe.progress)"
                    ].joined(separator: "|")
                )
            )
            edges.append(ImageGraphEdge(from: fromID, to: nodeID, label: "from"))
            edges.append(ImageGraphEdge(from: toID, to: nodeID, label: "to"))
            return nodeID
        case .layerComposite(let recipe):
            let backgroundID = try append(ImageNode.source(recipe.background))
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .layerComposite,
                    name: "LayerComposite",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: recipe.background.kindName,
                    filterCount: recipe.layers.count,
                    fingerprint: recipe.fingerprint
                )
            )
            edges.append(ImageGraphEdge(from: backgroundID, to: nodeID, label: "background"))
            return nodeID
        case .cachePolicy(let input, let policy):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .cachePolicy,
                    name: "CachePolicy.\(policy.rawValue)",
                    cachePolicy: policy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: 0,
                    fingerprint: node.resolutionFingerprint(profile: profile, derivative: derivative)
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        case .samplerDescriptor(let input, let descriptor):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .samplerDescriptor,
                    name: "SamplerDescriptor",
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: descriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: 0,
                    fingerprint: descriptor.fingerprint
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        }
    }

    private func allocateID() -> ImageGraphNodeID {
        defer { nextID += 1 }
        return ImageGraphNodeID(rawValue: nextID)
    }

    /// 连续滤镜节点从源端依次建图，每组配方只读取一次；不跨请求保存可变滤镜状态。
    private func appendFilterNodes(_ node: ImageNode) throws -> ImageGraphNodeID {
        let route = node.groupedFilterRoute()
        var inputID = try append(route.input)
        var inputFingerprint = route.input.nodeFingerprint
        let cachePolicy = route.input.resolvedCachePolicy
        let sourceKind = try route.input.resolvedPrimarySource().kindName
        for filters in route.groups.reversed() {
            let nodeID = allocateID()
            inputFingerprint = ImageNode.filterNodeFingerprint(inputFingerprint: inputFingerprint, filters: filters)
            nodes.append(ImageGraphNode(
                id: nodeID,
                kind: .filters,
                name: "Filters",
                cachePolicy: cachePolicy,
                samplerDescriptor: .default,
                sourceKind: sourceKind,
                filterCount: filters.count,
                fingerprint: ImageNode.resolutionFingerprint(
                    nodeFingerprint: inputFingerprint,
                    profile: profile,
                    derivative: derivative,
                    cachePolicy: cachePolicy,
                    samplerDescriptor: .default
                )
            ))
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            inputID = nodeID
        }
        return inputID
    }
}
