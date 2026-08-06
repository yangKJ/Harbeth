import XCTest
import Metal
@testable import Harbeth

final class PointwiseFusionTests: XCTestCase {
    private func makeTexture() throws -> MTLTexture {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let texture = try TextureLoader.makeTexture(
            width: 2,
            height: 2,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "PointwiseFusionTests"
        )
        let bytes: [UInt8] = [
            32, 64, 128, 255,
            180, 90, 40, 192,
            12, 220, 100, 128,
            240, 200, 160, 64
        ]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    func testPlannerFusesOnlyConsecutiveSupportedPointOperations() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.1),
            C7GaussianBlur(radius: 2),
            C7Saturation(saturation: 1.2),
            C7Exposure(exposure: 0.2)
        ]

        let execution = PointwiseFusionPlanner.makeExecutionFilters(filters)

        XCTAssertEqual(execution.count, 3)
        XCTAssertEqual((execution[0] as? C7FusedPointOperations)?.fusedOperationCount, 2)
        XCTAssertTrue(execution[1] is C7GaussianBlur)
        XCTAssertEqual((execution[2] as? C7FusedPointOperations)?.fusedOperationCount, 2)
    }

    func testFusionUsesOneFusedFilterNodeAndOneDispatchStage() throws {
        let texture = try makeTexture()
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.1),
            C7Saturation(saturation: 1.2),
            C7Exposure(exposure: 0.2)
        ]

        let diagnostics = try HarbethIO(element: texture, filters: filters).renderDiagnostics()

        XCTAssertEqual(diagnostics.optimizedGraphNodeCount, 2, "ImageNode diagnostics include the source node and the fused filter node.")
        XCTAssertEqual(diagnostics.stageCount, 1)
        XCTAssertEqual(diagnostics.optimizationPlan.mergedStageCount, 1)
        XCTAssertEqual(diagnostics.optimizationPlan.fusionEligibleNodeCount, 4)
        XCTAssertTrue(diagnostics.summary.contains("C7FusedPointOperations"))
    }

    func testFusedKernelMatchesOrderedStandaloneKernels() throws {
        let texture = try makeTexture()
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.08),
            C7Contrast(contrast: 1.15),
            C7Saturation(saturation: 0.85),
            C7Exposure(exposure: 0.25),
            C7Gamma(gamma: 1.1),
            C7Opacity(opacity: 0.7)
        ]
        let fused = try HarbethIO(element: texture, filters: filters).output()

        var standalone = texture
        for filter in filters {
            standalone = try HarbethIO(element: standalone, filters: [filter]).output()
        }

        guard let fusedBytes = fused.c7.bytes(), let standaloneBytes = standalone.c7.bytes() else {
            return XCTFail("Expected readable RGBA8 textures.")
        }
        XCTAssertEqual(fusedBytes.count, standaloneBytes.count)
        for (fusedValue, standaloneValue) in zip(fusedBytes, standaloneBytes) {
            XCTAssertEqual(Int(fusedValue), Int(standaloneValue), accuracy: 1)
        }
    }

    func testPlannerSplitsRunsAtTheFixedOperationLimit() {
        let filters: [C7FilterProtocol] = (0..<(PointwiseFusionPlanner.maximumOperationCount + 3)).map { index in
            C7Brightness(brightness: Float(index) * 0.001)
        }

        let execution = PointwiseFusionPlanner.makeExecutionFilters(filters)

        XCTAssertEqual(execution.count, 2)
        XCTAssertEqual((execution[0] as? C7FusedPointOperations)?.fusedOperationCount, PointwiseFusionPlanner.maximumOperationCount)
        XCTAssertEqual((execution[1] as? C7FusedPointOperations)?.fusedOperationCount, 3)
    }
}
