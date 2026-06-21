import XCTest
@testable import Harbeth

final class EditRecipeTests: XCTestCase {

    func testPreviewAndFinalContractsRemainSeparated() {
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(targetSize: CGSize(width: 320, height: 180), aspectPolicy: .fit),
            filters: [C7Brightness(brightness: 0.2)],
            previewProfile: .stablePreview,
            finalProfile: .exportQuality
        )

        let preview = recipe.contract(for: .preview)
        let final = recipe.contract(for: .final)

        XCTAssertEqual(preview.profile, .stablePreview)
        XCTAssertEqual(preview.renderIntent, .stable)
        XCTAssertEqual(preview.sourceTier, .stableReusable)
        XCTAssertEqual(final.profile, .exportQuality)
        XCTAssertEqual(final.renderIntent, .export)
        XCTAssertEqual(final.sourceTier, .fullResolutionReusable)
    }

    func testEditRecipePrependsGeometryFilters() {
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(
                cropRegion: ImageCropRegion(rect: CGRect(x: 0, y: 0, width: 10, height: 10)),
                targetSize: CGSize(width: 5, height: 5),
                aspectPolicy: .fit
            ),
            filters: [C7Brightness(brightness: 0.2)]
        )

        let filters = recipe.makeFilterChain(inputSize: C7Size(width: 10, height: 10))
        XCTAssertGreaterThanOrEqual(filters.count, 3)
        XCTAssertEqual(filters.first?.kernelContract.functionIdentity, "compute:C7Crop")
        XCTAssertEqual(filters.last?.kernelContract.functionIdentity, "compute:C7Brightness")
    }
}
