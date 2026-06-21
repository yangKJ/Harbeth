import XCTest
import Metal
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
