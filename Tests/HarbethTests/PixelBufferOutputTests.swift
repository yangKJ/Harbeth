import XCTest
import Metal
import CoreVideo
import CoreMedia
@testable import Harbeth

final class PixelBufferOutputTests: XCTestCase {

    func testPixelBufferPoolDescriptorCreatesMetalCompatibleBuffers() throws {
        let descriptor = RenderPixelBufferDescriptor(
            width: 3,
            height: 2,
            minimumBufferCount: 2
        )
        let pool = try HarbethPixelBufferPool(descriptor: descriptor)
        let pixelBuffer = try pool.makePixelBuffer()

        XCTAssertEqual(descriptor.width, 3)
        XCTAssertEqual(descriptor.height, 2)
        XCTAssertTrue(descriptor.fingerprint.contains("size=3x2"))
        XCTAssertEqual(CVPixelBufferGetWidth(pixelBuffer), 3)
        XCTAssertEqual(CVPixelBufferGetHeight(pixelBuffer), 2)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(pixelBuffer), kCVPixelFormatType_32BGRA)
        XCTAssertNotNil(CVPixelBufferGetIOSurface(pixelBuffer))
    }

    func testRenderPixelBufferCreatesIndependentOutputBuffer() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [40, 60, 80, 255])
        let pool = try HarbethPixelBufferPool(width: 2, height: 2)

        let output = try HarbethIO(
            element: input,
            filter: C7Brightness(brightness: 0.1)
        ).renderPixelBuffer(pool: pool)

        XCTAssertEqual(CVPixelBufferGetWidth(output), 2)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 2)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(output), kCVPixelFormatType_32BGRA)
    }

    func testRenderPixelBufferRespectsDerivativeOutputSize() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [120, 40, 20, 255])
        let derivative = ImageDerivativeSpec(
            name: "pixelBufferDerivative",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .exact(C7Size(width: 2, height: 3))
        )

        let output = try HarbethIO(
            element: input,
            filters: []
        ).renderPixelBuffer(profile: .stablePreview, derivative: derivative)

        XCTAssertEqual(CVPixelBufferGetWidth(output), 2)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 3)
    }

    func testBGRAPixelBufferContractPrefersDirectSingleTextureBridge() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 3,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 3, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertFalse(contract.planar)
        XCTAssertEqual(contract.planeCount, 1)
        XCTAssertEqual(contract.colorModel, .rgba)
        XCTAssertEqual(contract.nativeTextureLayout, .directSingleTexture)
        XCTAssertEqual(contract.planes.first?.metalPixelFormat, .bgra8Unorm)
        XCTAssertEqual(bridgePlan.loadStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.preservesOwnerReference)
    }

    func testBiPlanarPixelBufferContractExposesPlanesAndFallbackLoadStrategy() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertTrue(contract.planar)
        XCTAssertEqual(contract.planeCount, 2)
        XCTAssertEqual(contract.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.nativeTextureLayout, .planeTextures)
        XCTAssertEqual(contract.planes[0].width, 4)
        XCTAssertEqual(contract.planes[0].height, 4)
        XCTAssertEqual(contract.planes[0].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(contract.planes[1].width, 2)
        XCTAssertEqual(contract.planes[1].height, 2)
        XCTAssertEqual(contract.planes[1].metalPixelFormat, .rg8Unorm)
        XCTAssertTrue(contract.requiresYCbCrConversion)
        XCTAssertEqual(bridgePlan.loadStrategy, .cgImageFallback)
        XCTAssertFalse(bridgePlan.preservesOwnerReference)
        XCTAssertTrue(bridgePlan.requiresColorConversion)
    }

    func testRenderRequestTracksPixelBufferSourceContract() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 3,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 3, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        let request = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.1))
            .makeRenderRequest(profile: .stablePreview)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)

        XCTAssertEqual(request.source.kind, "pixelBuffer")
        XCTAssertEqual(request.source.cachePolicy, .persistent)
        XCTAssertEqual(request.compilationSource, .filtersPrimitive)
        XCTAssertEqual(renderRecipe.source.kind, "pixelBuffer")
        XCTAssertEqual(renderRecipe.alphaType, .premultiplied)
        XCTAssertEqual(renderRecipe.orientation, .up)
    }

    func testNodeRenderRecipeTracksSampleBufferSourceContract() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer,
              let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let node = HarbethImageNode.sampleBuffer(sampleBuffer)
            .applying(C7Brightness(brightness: 0.1))
        let request = try node.makeRenderRequest(profile: .stablePreview)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)

        XCTAssertEqual(request.source.kind, "sampleBuffer")
        XCTAssertEqual(renderRecipe.source.kind, "sampleBuffer")
        XCTAssertEqual(renderRecipe.alphaType, .premultiplied)
        XCTAssertEqual(renderRecipe.orientation, .up)
        XCTAssertEqual(request.diagnostics.compilationSource, .nodeGraph)
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = Shared.shared.defaultDevice.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = pixel[0]
            pixels[index + 1] = pixel[1]
            pixels[index + 2] = pixel[2]
            pixels[index + 3] = pixel[3]
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }
}
