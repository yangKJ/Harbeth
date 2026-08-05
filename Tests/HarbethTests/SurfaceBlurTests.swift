import Metal
import XCTest
@testable import Harbeth

final class SurfaceBlurTests: XCTestCase {

    func testPixelContractExposesTileHalo() {
        let filter = C7SurfaceBlur(radius: 8.25, threshold: 0.1)

        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 9))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
    }

    func testZeroRadiusAndThresholdPassThroughWithoutNaN() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeTexture(pixels: [
            [32, 64, 96, 128], [180, 120, 60, 255],
            [0, 0, 0, 0], [24, 48, 72, 96]
        ])

        let zeroRadius = try HarbethIO(
            element: input,
            filter: C7SurfaceBlur(radius: 0, threshold: 0.1)
        ).renderTexture(profile: .stablePreview)
        let zeroThreshold = try HarbethIO(
            element: input,
            filter: C7SurfaceBlur(radius: 8, threshold: 0)
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(readPixels(zeroRadius), readPixels(input))
        XCTAssertEqual(readPixels(zeroThreshold), readPixels(input))
    }

    func testBlurPreservesPremultipliedAlphaAtImageEdges() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeTexture(pixels: [
            [32, 64, 96, 128], [180, 120, 60, 255],
            [0, 0, 0, 0], [24, 48, 72, 96]
        ])
        var filter = C7SurfaceBlur(radius: 8, threshold: 1)
        filter.intensity = 1

        let output = try HarbethIO(element: input, filter: filter).renderTexture(profile: .stablePreview)
        let pixels = readPixels(output)

        XCTAssertEqual(pixels.count, 4)
        for pixel in pixels {
            XCTAssertLessThanOrEqual(pixel[0], pixel[3])
            XCTAssertLessThanOrEqual(pixel[1], pixel[3])
            XCTAssertLessThanOrEqual(pixel[2], pixel[3])
        }
    }

    private func makeTexture(pixels: [[UInt8]]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: 2,
            height: 2,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "surface-blur-input"
        )
        let bytes = pixels.flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func readPixels(_ texture: MTLTexture) -> [[UInt8]] {
        var bytes = [UInt8](repeating: 0, count: 16)
        texture.getBytes(
            &bytes,
            bytesPerRow: 8,
            from: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0
        )
        return stride(from: 0, to: bytes.count, by: 4).map { Array(bytes[$0..<$0 + 4]) }
    }
}
