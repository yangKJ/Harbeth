import XCTest
import Metal
import CoreVideo
@testable import Harbeth

final class HarbethContextTests: XCTestCase {

    func testContextCachesComputeRenderAndSamplerState() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let context = HarbethContext.shared
        context.resetCaches()

        _ = context.makeSamplerState()
        _ = context.makeSamplerState()

        let snapshot = context.debugCacheSnapshot()
        XCTAssertEqual(snapshot.samplerCount, 1)
        XCTAssertNotNil(context.commandQueue)
    }

    func testTexturePoolReusesExactTexture() throws {
        let texture = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "context-pool")
        Shared.shared.texturePool?.enqueueTextureSync(texture)
        let reused = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "context-pool")
        XCTAssertTrue(texture === reused)
    }

    func testPixelBufferBackedTextureRetainsOwnerReference() throws {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferWidthKey: 2,
                kCVPixelBufferHeightKey: 2,
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
            ] as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Expected pixel buffer.")
            return
        }

        let texture = try TextureLoader(with: pixelBuffer).texture
        let owner = TextureOwnerRegistry.owner(for: texture)
        XCTAssertNotNil(owner)
    }
}
