import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class RegionalProcessingContractTests: XCTestCase {

    func testCropNoOpReturnsTheRequestedSourceRegion() throws {
        let source = try makePatternTexture(width: 4, height: 4)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7CropBlit(rect: CGRect(x: 1, y: 1, width: 2, height: 2))
        ).output()

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(try bytes(in: output), [11, 12, 13, 255, 12, 13, 14, 255, 21, 22, 23, 255, 22, 23, 24, 255])
    }

    func testCopyRegionPasteBackToTheSameLocationIsPixelStable() throws {
        let source = try makePatternTexture(width: 4, height: 4)
        let before = try bytes(in: source)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7CopyRegionBlit(
                sourceRect: CGRect(x: 1, y: 1, width: 2, height: 2),
                destOrigin: MTLOrigin(x: 1, y: 1, z: 0)
            )
        ).output()

        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(output.height, 4)
        XCTAssertEqual(try bytes(in: output), before)
    }

    func testCopyRegionStagesOverlappingInPlaceMovesInEveryDirection() throws {
        let cases: [(name: String, source: CGRect, destination: MTLOrigin)] = [
            ("right", CGRect(x: 0, y: 1, width: 4, height: 3), MTLOrigin(x: 1, y: 1, z: 0)),
            ("left", CGRect(x: 1, y: 1, width: 4, height: 3), MTLOrigin(x: 0, y: 1, z: 0)),
            ("down", CGRect(x: 1, y: 0, width: 3, height: 4), MTLOrigin(x: 1, y: 1, z: 0)),
            ("up", CGRect(x: 1, y: 1, width: 3, height: 4), MTLOrigin(x: 1, y: 0, z: 0))
        ]

        for testCase in cases {
            let texture = try makePatternTexture(width: 5, height: 5)
            let before = try bytes(in: texture)
            let output: MTLTexture = try HarbethIO(
                element: texture,
                filter: C7CopyRegionBlit(sourceRect: testCase.source, destOrigin: testCase.destination)
            ).output()

            XCTAssertTrue(output === texture, testCase.name)
            XCTAssertEqual(
                try bytes(in: output),
                expectedBytes(afterCopying: testCase.source, to: testCase.destination, in: before, width: 5),
                testCase.name
            )
        }
    }

    func testTextureRegionRectRejectsNonIntegerAndEmptyRects() throws {
        XCTAssertNil(TextureRegionRect(rect: CGRect(x: 1.5, y: 1, width: 2, height: 2)))
        XCTAssertNil(TextureRegionRect(rect: CGRect(x: 1, y: 1, width: 0, height: 2)))
        XCTAssertNil(TextureRegionRect(rect: CGRect(x: 1, y: 1, width: CGFloat.nan, height: 2)))

        let huge = TextureRegionRect(x: Int.max, y: 0, width: 1, height: 1)
        XCTAssertFalse(huge.fits(in: try MaskTestHelpers.makeTexture(width: 2, height: 2)))
    }

    func testCropRejectsFractionalRegionBeforeMetalCopy() throws {
        let source = try makePatternTexture(width: 4, height: 4)
        XCTAssertThrowsError(try HarbethIO(
            element: source,
            filter: C7CropBlit(rect: CGRect(x: 1.5, y: 1, width: 2, height: 2))
        ).output()) { error in
            assertTextureCropFailure(error)
        }
    }

    func testCopyRegionRejectsFractionalSourceRegionAndNonZeroDepth() throws {
        let source = try makePatternTexture(width: 4, height: 4)

        XCTAssertThrowsError(try HarbethIO(
            element: source,
            filter: C7CopyRegionBlit(
                sourceRect: CGRect(x: 1.5, y: 1, width: 2, height: 2),
                destOrigin: MTLOrigin(x: 1, y: 1, z: 0)
            )
        ).output()) { error in
            assertTextureCropFailure(error)
        }

        XCTAssertThrowsError(try HarbethIO(
            element: source,
            filter: C7CopyRegionBlit(
                sourceRect: CGRect(x: 1, y: 1, width: 2, height: 2),
                destOrigin: MTLOrigin(x: 1, y: 1, z: 1)
            )
        ).output()) { error in
            assertTextureCropFailure(error)
        }
    }

    func testPointFilterReportsPointSamplingFootprint() {
        XCTAssertEqual(C7Brightness(brightness: 0.1).samplingFootprint, .point)
    }

    func testLegacyNeighborhoodDoesNotGuessASeparateHalo() {
        XCTAssertEqual(NeighborhoodProbeFilter().samplingFootprint, .dynamic)
        XCTAssertFalse(NeighborhoodProbeFilter().samplingFootprint.canAutoTile)
    }

    func testSamplingFootprintRejectsNegativeNeighborhoodRadius() {
        let footprint = SamplingFootprint.neighborhood(radius: -1)
        XCTAssertFalse(footprint.isValid)
        XCTAssertNil(footprint.haloRadius)
        XCTAssertFalse(footprint.canAutoTile)
    }

    func testSamplingFootprintUsesStableCodableShape() throws {
        let footprint = SamplingFootprint.neighborhood(radius: 12)
        let data = try JSONEncoder().encode(footprint)
        let decoded = try JSONDecoder().decode(SamplingFootprint.self, from: data)

        XCTAssertEqual(decoded, footprint)
        XCTAssertEqual(decoded.fingerprint, "neighborhood:12")
    }

    func testRegionContextRequiresWriteRegionInsideReadRegion() throws {
        let logical = CGRect(x: 0, y: 0, width: 100, height: 80)
        XCTAssertThrowsError(try TextureRegionContext(
            logicalExtent: logical,
            readRegion: CGRect(x: 10, y: 10, width: 20, height: 20),
            writeRegion: CGRect(x: 20, y: 20, width: 20, height: 20)
        )) { error in
            XCTAssertEqual(error as? TextureRegionContextError, .invalidWriteRegion)
        }
    }

    func testRegionContextExpandsAndClampsReadRegion() throws {
        let context = try TextureRegionContext(
            logicalExtent: CGRect(x: 0, y: 0, width: 100, height: 80),
            readRegion: CGRect(x: 2, y: 3, width: 10, height: 12),
            writeRegion: CGRect(x: 4, y: 5, width: 4, height: 4)
        )

        let expanded = try context.expandingReadRegion(by: 8)
        XCTAssertEqual(expanded.readRegion, CGRect(x: 0, y: 0, width: 20, height: 23))
        XCTAssertEqual(expanded.writeRegion, context.writeRegion)
        XCTAssertEqual(expanded.logicalExtent, context.logicalExtent)
    }

    func testTextureMappingContextKeepsIndependentInputAndOutputSpaces() throws {
        let context = try TextureMappingContext(
            inputLogicalExtent: CGRect(x: 0, y: 0, width: 12_000, height: 8_000),
            inputRegion: CGRect(x: 7_000, y: 1_000, width: 2_048, height: 2_048),
            outputLogicalExtent: CGRect(x: 0, y: 0, width: 12_000, height: 8_000),
            outputRegion: CGRect(x: 2_952, y: 1_000, width: 2_048, height: 2_048)
        )

        XCTAssertEqual(context.kernelValues, [
            7_000, 1_000, 12_000, 8_000,
            2_952, 1_000, 12_000, 8_000
        ])
    }

    func testTextureMappingContextRejectsRegionOutsideLogicalExtent() {
        XCTAssertThrowsError(try TextureMappingContext(
            inputLogicalExtent: CGRect(x: 0, y: 0, width: 100, height: 80),
            inputRegion: CGRect(x: 90, y: 0, width: 20, height: 20),
            outputLogicalExtent: CGRect(x: 0, y: 0, width: 100, height: 80),
            outputRegion: CGRect(x: 0, y: 0, width: 20, height: 20)
        ))
    }

    func testPointFootprintLeavesRegionUnchanged() throws {
        let context = try TextureRegionContext(
            logicalExtent: CGRect(x: 0, y: 0, width: 30, height: 30),
            readRegion: CGRect(x: 5, y: 5, width: 10, height: 10),
            writeRegion: CGRect(x: 6, y: 6, width: 4, height: 4)
        )

        let resolved = try context.expandingReadRegion(for: .point)
        XCTAssertEqual(resolved, context)
    }

    func testDynamicAndGlobalFootprintsCannotGuessReadRegion() throws {
        let context = try TextureRegionContext(logicalSize: C7Size(width: 32, height: 24))

        XCTAssertThrowsError(try context.expandingReadRegion(for: .dynamic)) { error in
            XCTAssertEqual(error as? TextureRegionContextError, .unsupportedFootprint)
        }
        XCTAssertThrowsError(try context.expandingReadRegion(for: .global)) { error in
            XCTAssertEqual(error as? TextureRegionContextError, .unsupportedFootprint)
        }
    }

    func testEmptyWriteRegionIsAnExplicitNoOp() throws {
        let context = try TextureRegionContext(
            logicalExtent: CGRect(x: 0, y: 0, width: 20, height: 20),
            readRegion: CGRect(x: 0, y: 0, width: 20, height: 20),
            writeRegion: .zero
        )
        XCTAssertTrue(context.writeRegion.isEmpty)
    }

    private func makePatternTexture(width: Int, height: Int) throws -> MTLTexture {
        let device = try MaskTestHelpers.requireDevice()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var pixels: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let value = UInt8(y * 10 + x)
                pixels.append(contentsOf: [value, value + 1, value + 2, 255])
            }
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func bytes(in texture: MTLTexture) throws -> [UInt8] {
        guard let bytes = texture.c7.bytes() else { throw HarbethError.texture2Image }
        return Array(bytes)
    }

    private func expectedBytes(
        afterCopying source: CGRect,
        to destination: MTLOrigin,
        in bytes: [UInt8],
        width: Int
    ) -> [UInt8] {
        var expected = bytes
        let sourceX = Int(source.origin.x)
        let sourceY = Int(source.origin.y)
        let copyWidth = Int(source.width)
        let copyHeight = Int(source.height)
        for y in 0..<copyHeight {
            for x in 0..<copyWidth {
                let sourceOffset = ((sourceY + y) * width + sourceX + x) * 4
                let destinationOffset = ((destination.y + y) * width + destination.x + x) * 4
                expected[destinationOffset..<(destinationOffset + 4)] = bytes[sourceOffset..<(sourceOffset + 4)]
            }
        }
        return expected
    }

    private func assertTextureCropFailure(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard let harbethError = error as? HarbethError else {
            XCTFail("Expected HarbethError.textureCropFailed, got \(error)", file: file, line: line)
            return
        }
        guard case .textureCropFailed = harbethError else {
            XCTFail("Expected HarbethError.textureCropFailed, got \(harbethError)", file: file, line: line)
            return
        }
    }
}

private struct NeighborhoodProbeFilter: C7FilterProtocol {
    var modifier: ModifierEnum { .compute(kernel: "RegionalProcessingContractProbe") }
    var factors: [Float] { [] }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
}
