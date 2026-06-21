import XCTest
import Metal
import CoreVideo
@testable import Harbeth

final class HarbethContextTests: XCTestCase {

    func testContextCachesComputeRenderAndSamplerState() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let context = Shared.shared.defaultContext
        context.resetCaches()

        _ = context.makeSamplerState()
        _ = context.makeSamplerState()

        let snapshot = context.debugCacheSnapshot()
        XCTAssertEqual(snapshot.samplerCount, 1)
        XCTAssertNotNil(context.commandQueue)
    }

    func testTexturePoolReusesExactTexture() throws {
        let texture = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "context-pool")
        Shared.shared.defaultTexturePool.enqueueTextureSync(texture)
        let reused = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "context-pool")
        XCTAssertTrue(texture === reused)
    }

    func testSharedOwnsDefaultRuntimeAndContextBridgesToIt() {
        Shared.shared.deinitDevice()

        let device = Shared.shared.defaultDevice
        let context = Shared.shared.defaultContext

        XCTAssertTrue(Shared.shared.hasDevice)
        XCTAssertTrue(Shared.shared.hasContext)
        XCTAssertTrue(context === HarbethContext.shared)
        XCTAssertTrue(context.device === device.device)
        XCTAssertTrue(context.commandQueue === device.commandQueue)
        XCTAssertTrue(context.texturePool === Shared.shared.defaultTexturePool)
    }

    func testSharedDeinitDeviceResetsDefaultRuntime() {
        _ = Shared.shared.defaultDevice
        _ = Shared.shared.defaultContext
        _ = Shared.shared.defaultTexturePool

        XCTAssertTrue(Shared.shared.hasDevice)
        XCTAssertTrue(Shared.shared.hasContext)

        Shared.shared.deinitDevice()

        XCTAssertFalse(Shared.shared.hasDevice)
        XCTAssertFalse(Shared.shared.hasContext)

        let newDevice = Shared.shared.defaultDevice
        let newContext = Shared.shared.defaultContext
        XCTAssertTrue(Shared.shared.hasDevice)
        XCTAssertTrue(Shared.shared.hasContext)
        XCTAssertTrue(newContext.device === newDevice.device)
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
