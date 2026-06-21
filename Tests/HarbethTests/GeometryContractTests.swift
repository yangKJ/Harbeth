import XCTest
import Metal
@testable import Harbeth

final class GeometryContractTests: XCTestCase {

    func testNormalizedCropRegionResolvesIntoPixelRect() {
        let region = ImageCropRegion(
            rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            coordinateSpace: .normalized
        )
        let resolved = region.resolvedRect(in: CGSize(width: 200, height: 100))
        XCTAssertEqual(resolved, CGRect(x: 50, y: 25, width: 100, height: 50))
        XCTAssertEqual(region.resolvedOutputSize(in: CGSize(width: 200, height: 100)), C7Size(width: 100, height: 50))
    }

    func testAspectFillRecipeProducesResizeAndCropContract() {
        let recipe = ImageTransformRecipe(
            targetSize: CGSize(width: 4, height: 4),
            aspectPolicy: .fill
        )
        let filters = recipe.makeFilters(inputSize: C7Size(width: 8, height: 4))
        XCTAssertEqual(filters.count, 2)
        XCTAssertEqual(filters.first?.kernelContract.functionIdentity, "compute:C7LanczosResize")
        XCTAssertEqual(filters.last?.kernelContract.functionIdentity, "compute:C7Crop")
    }

    func testTransformRecipeCanAddCropAndVerticalFlip() {
        let recipe = ImageTransformRecipe(
            cropRegion: ImageCropRegion(rect: CGRect(x: 1, y: 1, width: 6, height: 2)),
            targetSize: CGSize(width: 3, height: 1),
            aspectPolicy: .fit,
            flipsVertically: true
        )
        let filters = recipe.makeFilters(inputSize: C7Size(width: 8, height: 4))
        XCTAssertEqual(filters.count, 3)
        XCTAssertEqual(filters.first?.kernelContract.functionIdentity, "compute:C7Crop")
        XCTAssertEqual(filters.last?.kernelContract.functionIdentity, "compute:C7LanczosResize")
    }
}
