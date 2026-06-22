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
