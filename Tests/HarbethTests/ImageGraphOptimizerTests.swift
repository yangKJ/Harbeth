import XCTest
import Metal
import CoreGraphics
@testable import Harbeth

final class ImageGraphOptimizerTests: XCTestCase {

    func testNodeBuildsStableImageGraph() throws {
        let input = try makeTexture(width: 4, height: 4)
        let node = ImageNode
            .texture(input)
            .applying(filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ])
            .withCachePolicy(.persistent)

        let graph = try node.makeImageGraph()

        XCTAssertGreaterThanOrEqual(graph.nodeCount, 3)
        XCTAssertGreaterThanOrEqual(graph.edgeCount, 2)
        XCTAssertTrue(graph.persistentBoundaryCount >= 1)
        XCTAssertFalse(graph.fingerprint.isEmpty)
    }

    func testOptimizerMergesAdjacentTransientFilterNodes() throws {
        let input = try makeTexture(width: 4, height: 4)
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .applying(C7Contrast(contrast: 1.1))

        let graph = try node.makeImageGraph()
        let optimized = try node.makeOptimizedImageGraph()

        XCTAssertTrue(graph.nodeCount > optimized.graph.nodeCount)
        XCTAssertTrue(optimized.decisions.contains("mergeAdjacentFilterNodes"))
    }

    func testOptimizerPreservesTransitionBoundary() throws {
        let from = try makeTexture(width: 2, height: 2)
        let to = try makeTexture(width: 2, height: 2)
        let node = ImageNode.transition(
            TransitionRecipe(from: .texture(from), to: .texture(to), kernel: .dissolve, progress: 0.5)
        )

        let optimized = try node.makeOptimizedImageGraph()

        XCTAssertTrue(optimized.graph.nodes.contains(where: { $0.kind == .transition }))
        XCTAssertTrue(optimized.graph.persistentBoundaryCount >= 1)
    }

    func testOptimizerPreservesSamplerBoundaryForTransientFilterNodes() {
        let sourceID = ImageGraphNodeID(rawValue: 0)
        let firstFilterID = ImageGraphNodeID(rawValue: 1)
        let secondFilterID = ImageGraphNodeID(rawValue: 2)
        let graph = ImageGraph(
            nodes: [
                .init(
                    id: sourceID,
                    kind: .source,
                    name: "Source.texture",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 0,
                    fingerprint: "source"
                ),
                .init(
                    id: firstFilterID,
                    kind: .filters,
                    name: "NearestFilters",
                    cachePolicy: .transient,
                    samplerDescriptor: .nearest,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "nearest"
                ),
                .init(
                    id: secondFilterID,
                    kind: .filters,
                    name: "LinearFilters",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "linear"
                )
            ],
            edges: [
                .init(from: sourceID, to: firstFilterID),
                .init(from: firstFilterID, to: secondFilterID)
            ],
            rootNodeID: secondFilterID,
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec
        )

        let optimized = ImageGraphOptimizer.optimize(graph)

        XCTAssertEqual(optimized.graph.nodes.count, 3)
        XCTAssertEqual(optimized.graph.edges.count, 2)
        XCTAssertTrue(optimized.decisions.contains("preserveSamplerBoundary"))
        XCTAssertFalse(optimized.decisions.contains("mergeAdjacentFilterNodes"))
    }

    func testOptimizerMergesAdjacentTransientKernelNodes() {
        let sourceID = ImageGraphNodeID(rawValue: 0)
        let firstKernelID = ImageGraphNodeID(rawValue: 1)
        let secondKernelID = ImageGraphNodeID(rawValue: 2)
        let graph = ImageGraph(
            nodes: [
                .init(
                    id: sourceID,
                    kind: .source,
                    name: "Source.texture",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 0,
                    fingerprint: "source"
                ),
                .init(
                    id: firstKernelID,
                    kind: .kernel,
                    name: "KernelA",
                    cachePolicy: .transient,
                    samplerDescriptor: .nearest,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "kernel-a"
                ),
                .init(
                    id: secondKernelID,
                    kind: .kernel,
                    name: "KernelB",
                    cachePolicy: .transient,
                    samplerDescriptor: .nearest,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "kernel-b"
                )
            ],
            edges: [
                .init(from: sourceID, to: firstKernelID),
                .init(from: firstKernelID, to: secondKernelID)
            ],
            rootNodeID: secondKernelID,
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec
        )

        let optimized = ImageGraphOptimizer.optimize(graph)

        XCTAssertEqual(optimized.graph.nodes.count, 2)
        XCTAssertEqual(optimized.graph.edges.count, 1)
        XCTAssertTrue(optimized.decisions.contains("mergeAdjacentKernelNodes"))
        XCTAssertEqual(optimized.graph.nodes.last?.kind, .kernel)
        XCTAssertEqual(optimized.graph.nodes.last?.filterCount, 2)
        XCTAssertEqual(optimized.graph.nodes.last?.samplerDescriptor, .nearest)
        XCTAssertEqual(optimized.graph.rootNodeID, secondKernelID)
    }

    func testOptimizerCollapsesRedundantTransientCachePolicyWrapper() throws {
        let input = try makeTexture(width: 4, height: 4)
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .withCachePolicy(.transient)

        let graph = try node.makeImageGraph()
        let optimized = try node.makeOptimizedImageGraph()

        XCTAssertTrue(graph.nodes.contains(where: { $0.kind == .cachePolicy }))
        XCTAssertFalse(optimized.graph.nodes.contains(where: { $0.kind == .cachePolicy }))
        XCTAssertTrue(optimized.decisions.contains("collapseRedundantCachePolicyWrapper"))
        XCTAssertEqual(optimized.graph.rootNodeID, optimized.graph.nodes.last?.id)
    }

    func testOptimizerCollapsesRedundantSamplerWrapper() throws {
        let input = try makeTexture(width: 4, height: 4)
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .withSamplerDescriptor(.default)

        let graph = try node.makeImageGraph()
        let optimized = try node.makeOptimizedImageGraph()

        XCTAssertTrue(graph.nodes.contains(where: { $0.kind == .samplerDescriptor }))
        XCTAssertFalse(optimized.graph.nodes.contains(where: { $0.kind == .samplerDescriptor }))
        XCTAssertTrue(optimized.decisions.contains("collapseRedundantSamplerWrapper"))
        XCTAssertEqual(optimized.graph.rootNodeID, optimized.graph.nodes.last?.id)
    }

    func testOptimizerMergesTransientFiltersAcrossTransparentWrapper() throws {
        let input = try makeTexture(width: 4, height: 4)
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .withSamplerDescriptor(.default)
            .applying(C7Contrast(contrast: 1.1))

        let optimized = try node.makeOptimizedImageGraph()

        XCTAssertEqual(optimized.graph.nodes.filter { $0.kind == .filters }.count, 1)
        XCTAssertTrue(optimized.decisions.contains("collapseRedundantSamplerWrapper"))
        XCTAssertTrue(optimized.decisions.contains("mergeAdjacentFilterNodes"))
        XCTAssertEqual(optimized.graph.nodes.last?.filterCount, 2)
    }

    func testOptimizerPreservesEditRecipeSemanticBoundary() throws {
        let input = try makeTexture(width: 4, height: 4)
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: 2, height: 2),
                        aspectPolicy: .fit
                    )
                )
            )
            .applying(C7Contrast(contrast: 1.1))

        let optimized = try node.makeOptimizedImageGraph()

        XCTAssertEqual(optimized.graph.nodes.filter { $0.kind == .recipe }.count, 1)
        XCTAssertEqual(optimized.graph.nodes.filter { $0.kind == .filters }.count, 2)
        XCTAssertFalse(optimized.decisions.contains("mergeAdjacentFilterNodes"))
    }

    func testOptimizerKeepsRewriteOrderAndRootAcrossSparseIDs() {
        let source = makeNode(10, kind: .source)
        let first = makeNode(30, kind: .filters)
        let sampler = makeNode(50, kind: .samplerDescriptor)
        let second = makeNode(90, kind: .filters)
        let cache = makeNode(100, kind: .cachePolicy)
        let graph = ImageGraph(
            nodes: [cache, second, source, sampler, first],
            edges: [.init(from: source.id, to: first.id, label: "base"),
                    .init(from: first.id, to: sampler.id), .init(from: sampler.id, to: second.id),
                    .init(from: second.id, to: cache.id)],
            rootNodeID: cache.id, profile: .stablePreview, derivative: RenderProfile.stablePreview.defaultDerivativeSpec
        )
        let result = ImageGraphOptimizer.optimize(graph)
        XCTAssertEqual(result.decisions, ["collapseRedundantSamplerWrapper", "mergeAdjacentFilterNodes",
                                          "collapseRedundantCachePolicyWrapper"])
        XCTAssertEqual(result.graph.nodes.map(\.id), [source.id, second.id])
        XCTAssertEqual(result.graph.nodes.last?.fingerprint, "f30||f90")
        XCTAssertEqual(result.graph.nodes.last?.filterCount, 2)
        XCTAssertEqual(result.graph.edges, [.init(from: source.id, to: second.id, label: "base")])
        XCTAssertEqual(result.graph.rootNodeID, second.id)
    }

    func testDuplicateEdgesPreventMergeUntilFinalDeduplication() {
        let source = makeNode(0, kind: .source)
        let first = makeNode(20, kind: .filters)
        let second = makeNode(40, kind: .filters)
        let shared = ImageGraphEdge(from: first.id, to: second.id)
        let graph = ImageGraph(
            nodes: [source, first, second],
            edges: [.init(from: source.id, to: first.id), shared, shared],
            rootNodeID: second.id, profile: .stablePreview, derivative: RenderProfile.stablePreview.defaultDerivativeSpec
        )
        XCTAssertEqual(graph.sharedDependencyNodeCount, 1)
        XCTAssertEqual(graph.outgoingEdgeCount(for: first.id), 2)
        let result = ImageGraphOptimizer.optimize(graph)
        XCTAssertEqual(result.graph.nodes, graph.nodes)
        XCTAssertEqual(result.decisions, ["preserveSharedInputDependency"])
        XCTAssertEqual(result.graph.edges, [.init(from: source.id, to: first.id), shared])
        XCTAssertEqual(result.graph.sharedDependencyNodeCount, 0)
    }

    func testRewrittenMultiInputEdgesKeepTheirExistingSelectionOrder() {
        let source = makeNode(0, kind: .source)
        let first = makeNode(10, kind: .filters)
        let otherSource = makeNode(20, kind: .source)
        let sampler = makeNode(30, kind: .samplerDescriptor)
        let second = makeNode(40, kind: .filters)
        let graph = ImageGraph(
            nodes: [source, first, otherSource, sampler, second],
            edges: [.init(from: source.id, to: first.id), .init(from: first.id, to: sampler.id),
                    .init(from: otherSource.id, to: second.id, label: "alternate"),
                    .init(from: sampler.id, to: second.id, label: "chain")],
            rootNodeID: second.id, profile: .stablePreview, derivative: RenderProfile.stablePreview.defaultDerivativeSpec
        )
        let result = ImageGraphOptimizer.optimize(graph)
        // wrapper 重接后，首次输入仍是 otherSource；中途排序会错误地选择 first 并合并。
        XCTAssertEqual(result.decisions, ["collapseRedundantSamplerWrapper"])
        XCTAssertEqual(result.graph.nodes.map(\.id), [source.id, first.id, otherSource.id, second.id])
        XCTAssertEqual(result.graph.edges, [.init(from: source.id, to: first.id),
                                           .init(from: first.id, to: second.id, label: "chain"),
                                           .init(from: otherSource.id, to: second.id, label: "alternate")])
    }

    private func makeNode(_ id: Int, kind: ImageGraphNodeKind) -> ImageGraphNode {
        ImageGraphNode(
            id: .init(rawValue: id),
            kind: kind,
            name: "n\(id)",
            cachePolicy: .transient,
            samplerDescriptor: .default,
            filterCount: kind == .filters ? 1 : 0,
            fingerprint: "f\(id)"
        )
    }

    private func makeTexture(width: Int, height: Int) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Could not create Metal texture.")
        }
        return texture
    }
}
