import Metal
import XCTest
@testable import Harbeth

final class DocumentBinarizationTests: XCTestCase {

    func testUsesLocalBackgroundPipeline() {
        let filter = C7DocumentBinarization(radius: 24, threshold: 0.2, softness: 0)

        XCTAssertEqual(filter.pipelineExecutionStyle, .sequential)
        XCTAssertEqual(filter.pipelineFilters.count, 1)
        XCTAssertTrue(filter.pipelineFilters[0] is MPSGaussianBlur)
        XCTAssertEqual(filter.pipelineOtherInputCount, 1)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 96))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
        XCTAssertEqual(filter.radius, 24)
        XCTAssertEqual(filter.threshold, 0.2)
        XCTAssertEqual(filter.softness, 0)
    }

    func testParametersClampToDocumentSafeRanges() {
        let filter = C7DocumentBinarization(radius: 0, threshold: 2, softness: -1)

        XCTAssertEqual(filter.radius, 1)
        XCTAssertEqual(filter.threshold, 0.5)
        XCTAssertEqual(filter.softness, 0)
    }

    func testUniformPaperAndDarkInkProduceBinarySeparation() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeDocumentTexture()

        let output = try HarbethIO(
            element: input,
            filter: C7DocumentBinarization(radius: 2, threshold: 0.08, softness: 0)
        ).renderTexture(profile: .stablePreview)
        let bytes = try XCTUnwrap(output.c7.bytes())

        XCTAssertEqual(bytes[0], 0)
        XCTAssertEqual(bytes[(3 * 4 + 3) * 4], 255)
        XCTAssertEqual(bytes[3], 255)
    }

    func testSemitransparentPaperProducesValidPremultipliedOutput() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeSolidTexture(pixel: [100, 100, 100, 128])

        let output = try HarbethIO(
            element: input,
            filter: C7DocumentBinarization(radius: 2, threshold: 0.08, softness: 0)
        ).renderTexture(profile: .stablePreview)
        let bytes = try XCTUnwrap(output.c7.bytes())

        XCTAssertEqual(Array(bytes[0..<4]), [128, 128, 128, 128])
    }

    private func makeDocumentTexture() throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: 4,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "document-binarization-input"
        )
        var bytes = [UInt8](repeating: 220, count: 4 * 4 * 4)
        for pixel in 0..<16 {
            bytes[pixel * 4 + 3] = 255
        }
        bytes[0] = 20
        bytes[1] = 20
        bytes[2] = 20
        texture.replace(
            region: MTLRegionMake2D(0, 0, 4, 4),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 16
        )
        return texture
    }

    private func makeSolidTexture(pixel: [UInt8]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: 4,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "document-binarization-alpha-input"
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
}
