import XCTest
import Metal
@testable import Harbeth

final class NativeReplacementFiltersTests: XCTestCase {

    func testUnsharpMaskIdentityKeepsSinglePixelReadable() throws {
        let texture = try makeTexture(width: 1, height: 1, pixels: [120, 80, 40, 255])
        let output: MTLTexture = try HarbethIO(
            element: texture,
            filter: C7UnsharpMask(radius: 2, intensity: 0, threshold: 0)
        ).output()

        let pixel = try pixel(in: output, x: 0, y: 0)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 120, accuracy: 1)
        XCTAssertEqual(pixel.green, 80, accuracy: 1)
        XCTAssertEqual(pixel.blue, 40, accuracy: 1)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testUnsharpMaskEnhancesCenterContrast() throws {
        let texture = try makeTexture(
            width: 3,
            height: 1,
            pixels: [
                60, 60, 60, 255,
                140, 140, 140, 255,
                60, 60, 60, 255
            ]
        )
        let output: MTLTexture = try HarbethIO(
            element: texture,
            filter: C7UnsharpMask(radius: 4, intensity: 1.5, threshold: 0)
        ).output()

        let center = try pixel(in: output, x: 1, y: 0)
        XCTAssertGreaterThan(center.red, 140)
    }

    func testLanczosResizeProducesRequestedOutputSize() throws {
        let texture = try makeTexture(
            width: 2,
            height: 2,
            pixels: [
                255, 0, 0, 255, 0, 255, 0, 255,
                0, 0, 255, 255, 255, 255, 255, 255
            ]
        )
        let output: MTLTexture = try HarbethIO(
            element: texture,
            filter: C7LanczosResize(width: 5, height: 3)
        ).output()

        XCTAssertEqual(output.width, 5)
        XCTAssertEqual(output.height, 3)

        let center = try pixel(in: output, x: 2, y: 1)
        XCTAssertGreaterThan(center.alpha, 0)
        XCTAssertTrue((0...255).contains(Int(center.red)))
        XCTAssertTrue((0...255).contains(Int(center.green)))
        XCTAssertTrue((0...255).contains(Int(center.blue)))
    }

    func testNoiseReductionLowAmountIsNearIdentity() throws {
        let texture = try makeTexture(width: 1, height: 1, pixels: [90, 140, 200, 255])
        let output: MTLTexture = try HarbethIO(
            element: texture,
            filter: C7NoiseReduction(radius: 3, amount: 0, edgePreservation: 0.8)
        ).output()

        let pixel = try pixel(in: output, x: 0, y: 0)
        XCTAssertEqual(pixel.red, 90, accuracy: 1)
        XCTAssertEqual(pixel.green, 140, accuracy: 1)
        XCTAssertEqual(pixel.blue, 200, accuracy: 1)
    }

    func testNoiseReductionSmoothsIsolatedHotPixelWithoutFlatteningEdges() throws {
        let texture = try makeTexture(
            width: 3,
            height: 1,
            pixels: [
                30, 30, 30, 255,
                220, 220, 220, 255,
                30, 30, 30, 255
            ]
        )
        let output: MTLTexture = try HarbethIO(
            element: texture,
            filter: C7NoiseReduction(radius: 2, amount: 1, edgePreservation: 0.9)
        ).output()

        let left = try pixel(in: output, x: 0, y: 0)
        let center = try pixel(in: output, x: 1, y: 0)
        let right = try pixel(in: output, x: 2, y: 0)

        XCTAssertLessThan(center.red, 220)
        XCTAssertLessThan(abs(Int(left.red) - 30), 20)
        XCTAssertLessThan(abs(Int(right.red) - 30), 20)
    }

    private func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.textureLoader
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func pixel(in texture: MTLTexture, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= ((y * texture.width + x) * 4 + 4) else {
            throw HarbethError.texture2Image
        }
        let offset = (y * texture.width + x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}
