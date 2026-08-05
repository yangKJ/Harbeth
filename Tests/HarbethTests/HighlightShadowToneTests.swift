import Metal
import XCTest
@testable import Harbeth

final class HighlightShadowToneTests: XCTestCase {

    func testPipelineBuildsLocalGaussianReference() {
        let filter = C7HighlightShadowTone(shadows: 0.4, highlights: -0.3, radius: 24)

        XCTAssertEqual(filter.pipelineExecutionStyle, .sequential)
        XCTAssertEqual(filter.pipelineFilters.count, 1)
        XCTAssertTrue(filter.pipelineFilters[0] is MPSGaussianBlur)
        XCTAssertEqual(filter.pipelineOtherInputCount, 1)
        XCTAssertEqual(filter.factors, [0.4, -0.3, 0, 0])
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 96))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
    }

    func testParametersClampAndZeroRadiusUsesIdentityReferenceStage() {
        let filter = C7HighlightShadowTone(
            shadows: 4,
            highlights: -4,
            midtones: 2,
            contrast: -2,
            radius: -10
        )

        XCTAssertEqual(filter.shadows, 1)
        XCTAssertEqual(filter.highlights, -1)
        XCTAssertEqual(filter.midtones, 1)
        XCTAssertEqual(filter.contrast, -1)
        XCTAssertEqual(filter.radius, 0)
        XCTAssertTrue(filter.pipelineFilters[0] is C7GaussianBlur)
    }

    func testZeroAdjustmentsPreservePremultipliedPixelExactly() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let source = try makeTexture(pixel: [48, 72, 96, 128])

        let output = try HarbethIO(
            element: source,
            filter: C7HighlightShadowTone(radius: 8)
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(readPixel(output), [48, 72, 96, 128])
    }

    func testActiveAdjustmentPreservesPremultipliedAlphaInvariant() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let source = try makeTexture(pixel: [24, 40, 56, 128])

        let output = try HarbethIO(
            element: source,
            filter: C7HighlightShadowTone(shadows: 0.6, highlights: -0.2, radius: 8)
        ).renderTexture(profile: .stablePreview)
        let pixel = readPixel(output)

        XCTAssertEqual(pixel[3], 128)
        XCTAssertLessThanOrEqual(pixel[0], pixel[3])
        XCTAssertLessThanOrEqual(pixel[1], pixel[3])
        XCTAssertLessThanOrEqual(pixel[2], pixel[3])
    }

    private func makeTexture(pixel: [UInt8]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: 4,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "highlight-shadow-tone-test"
        )
        let bytes = Array(repeating: pixel, count: 16).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 4, 4),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 16
        )
        return texture
    }

    private func readPixel(_ texture: MTLTexture) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &pixel,
            bytesPerRow: 4,
            from: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0
        )
        return pixel
    }
}
