//
//  DistinctiveStylizationFilterTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/5.
//

import Metal
import XCTest
@testable import Harbeth

final class DistinctiveStylizationFilterTests: XCTestCase {

    func testPalettizeSanitizesPaletteAndDeclaresSameRegionContract() {
        let filter = C7Palettize(
            palette: [
                .init(red: .nan, green: -1, blue: 2),
                .init(red: 0.25, green: 0.5, blue: 0.75)
            ]
        )

        XCTAssertEqual(filter.palette[0], .init(red: 0, green: 0, blue: 1))
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .point)
        XCTAssertEqual(filter.kernelPixelContract.coordinateDependency, .local)
        XCTAssertEqual(filter.kernelPixelContract.globalDependency, .none)
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
        XCTAssertEqual(filter.kernelParameterBindings.count, 3)
    }

    func testPalettizeUsesNearestColorAndPreservesPremultipliedAlpha() throws {
        let source = try makeTexture(width: 2, height: 1, pixels: [
            230, 20, 20, 255,
            10, 90, 10, 128
        ])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7Palettize(
                palette: [
                    .init(red: 1, green: 0, blue: 0),
                    .init(red: 0, green: 1, blue: 0)
                ]
            )
        ).output()

        XCTAssertEqual(read(output), [
            255, 0, 0, 255,
            0, 128, 0, 128
        ])
    }

    func testCMYKHalftoneDeclaresDynamicFullImageContract() {
        let filter = C7CMYKHalftone(fractionalWidth: 0.05)

        XCTAssertEqual(filter.modifier, .compute(kernel: "C7CMYKHalftone"))
        XCTAssertEqual(filter.memoryAccessPattern, .neighborhood)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .dynamic)
        XCTAssertEqual(filter.kernelPixelContract.coordinateDependency, .fullImage)
        XCTAssertEqual(filter.kernelPixelContract.globalDependency, .imageDimensions)
        XCTAssertFalse(filter.kernelPixelContract.canAutoTile)
        XCTAssertEqual(
            filter.conservativeSampleDisplacementFraction,
            0.05 * Float(2).squareRoot(),
            accuracy: 0.0001
        )
    }

    func testCMYKHalftoneZeroIntensityPreservesPixels() throws {
        let pixels: [UInt8] = [
            255, 0, 0, 255,
            0, 180, 0, 200,
            0, 0, 128, 128,
            64, 32, 16, 64
        ]
        let source = try makeTexture(width: 2, height: 2, pixels: pixels)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7CMYKHalftone(fractionalWidth: 0.1, intensity: 0)
        ).output()

        XCTAssertEqual(read(output), pixels)
    }

    func testCMYKHalftoneProducesPrintScreenAndPreservesAlpha() throws {
        let pixels: [UInt8] = [
            255, 0, 0, 255,
            0, 180, 0, 200,
            0, 0, 128, 128,
            64, 32, 16, 64
        ]
        let source = try makeTexture(width: 2, height: 2, pixels: pixels)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7CMYKHalftone(fractionalWidth: 0.1)
        ).output()
        let outputPixels = read(output)

        XCTAssertNotEqual(outputPixels, pixels)
        XCTAssertEqual(stride(from: 3, to: pixels.count, by: 4).map { outputPixels[$0] }, [255, 200, 128, 64])
    }

    private func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        guard pixels.count == width * height * 4 else {
            throw HarbethError.filterParameterInvalid("RGBA8 dimensions do not match the pixel count.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func read(_ texture: MTLTexture) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(
            &pixels,
            bytesPerRow: texture.width * 4,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        return pixels
    }
}
