import XCTest
import Metal
import CoreVideo
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
