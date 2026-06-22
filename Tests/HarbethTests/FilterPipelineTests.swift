import XCTest
import Metal
@testable import Harbeth

final class FilterPipelineTests: XCTestCase {

    func testCombinationFiltersUsePipelineProtocol() {
        let filter = C7CombinationCinematic(intensity: 0.7)
        let erased: C7FilterProtocol = filter

        XCTAssertTrue(erased is C7FilterPipelineProtocol)
        XCTAssertEqual(filter.pipelineExecutionStyle, .sequential)
        XCTAssertEqual(filter.pipelineFilters.count, 5)
    }

    func testRecipeDescriptorTracksPipelineFingerprintChanges() {
        let filter = C7CombinationVintage(intensity: 0.8)
        let initialDescriptor = filter.recipeDescriptor

        filter.dustIntensity = 0.55
        let updatedDescriptor = filter.recipeDescriptor

        XCTAssertNotEqual(initialDescriptor.fingerprint, updatedDescriptor.fingerprint)
        XCTAssertFalse(updatedDescriptor.pipelineFilterFingerprints.isEmpty)
        XCTAssertNotNil(updatedDescriptor.finalFilterFingerprint)
    }

    func testRenderGraphMarksPipelineFilterAsCombinationNode() {
        let plan = GraphCompiler.compile(
            filters: [C7CombinationBeautiful(intensity: 0.6)],
            inputSize: C7Size(width: 32, height: 32),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.graph.nodes.count, 1)
        XCTAssertEqual(plan.graph.nodes.first?.kind, .combination)
        XCTAssertTrue(plan.graph.nodes.first?.breaksFusion ?? false)
    }

    func testLegacyCombinationBaseSubclassRemainsCompatible() {
        let plan = GraphCompiler.compile(
            filters: [LegacyCompatibilityCombination()],
            inputSize: C7Size(width: 16, height: 16),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.graph.nodes.first?.kind, .combination)
    }

    func testPipelineCombinationRendersTexture() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let input = try TextureLoader.makeTexture(width: 8, height: 6, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "filter-pipeline-input")

        let output: MTLTexture = try HarbethIO(
            element: input,
            filters: [C7CombinationVintageFilm(intensity: 0.75)]
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(output.width, 8)
        XCTAssertEqual(output.height, 6)
    }
}

@available(*, deprecated)
private final class LegacyCompatibilityCombination: C7CombinationBase {
    override var modifier: ModifierEnum {
        .compute(kernel: "C7Brightness")
    }

    override var factors: [Float] {
        [0.1]
    }

    override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        []
    }
}
