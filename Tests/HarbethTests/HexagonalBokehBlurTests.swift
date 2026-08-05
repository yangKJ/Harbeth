//
//  HexagonalBokehBlurTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/5.
//

import Metal
import XCTest
@testable import Harbeth

final class HexagonalBokehBlurTests: XCTestCase {

    func testPublicParametersAndPixelContract() {
        let filter = C7HexagonalBokehBlur(radius: 6, brightness: 0.5, angle: 30)

        XCTAssertEqual(filter.pipelineExecutionStyle, .sequential)
        XCTAssertEqual(filter.pipelineFilters.count, 2)
        XCTAssertEqual(filter.radius, 6, accuracy: 0.0001)
        XCTAssertEqual(filter.brightness, 0.5, accuracy: 0.0001)
        XCTAssertEqual(filter.angle, 30, accuracy: 0.0001)
        XCTAssertEqual(filter.kernelPixelContract.inputAlphaExpectation, .premultiplied)
        XCTAssertEqual(filter.kernelPixelContract.outputAlpha, .premultiplied)
        XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
    }

    func testRadiusZeroPreservesEveryPixel() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeImpulseTexture(size: 9, alpha: 192)

        let output = try HarbethIO(
            element: input,
            filter: C7HexagonalBokehBlur(radius: 0, brightness: 2, angle: 45)
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(readPixels(output), readPixels(input))
    }

    func testBlurSpreadsImpulseAndPreservesAlpha() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeImpulseTexture(size: 17, alpha: 255)

        let output = try HarbethIO(
            element: input,
            filter: C7HexagonalBokehBlur(radius: 6, angle: 0)
        ).renderTexture(profile: .stablePreview)

        XCTAssertLessThan(pixel(output, x: 8, y: 8)[0], 255)
        XCTAssertGreaterThan(pixel(output, x: 11, y: 8)[0], 0)
        XCTAssertEqual(pixel(output, x: 8, y: 8)[3], 255)
        XCTAssertEqual(pixel(output, x: 11, y: 8)[3], 255)
    }

    func testAngleChangesHexagonalSamplingFootprint() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeImpulseTexture(size: 17, alpha: 255)

        let horizontalAperture = try HarbethIO(
            element: input,
            filter: C7HexagonalBokehBlur(radius: 6, angle: 0)
        ).renderTexture(profile: .stablePreview)
        let rotatedAperture = try HarbethIO(
            element: input,
            filter: C7HexagonalBokehBlur(radius: 6, angle: 30)
        ).renderTexture(profile: .stablePreview)

        XCTAssertNotEqual(readPixels(horizontalAperture), readPixels(rotatedAperture))
    }

    func testZeroCoCLeavesTextureUntouched() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeImpulseTexture(size: 9, alpha: 192)
        let coc = try makeSolidTexture(size: 9, value: 0)

        let output = try HarbethIO(
            element: input,
            filter: C7HexagonalBokehBlur(radius: 8, brightness: 1, cocTexture: coc)
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(readPixels(output), readPixels(input))
    }

    func testLowerResolutionCoCUsesNormalizedCoordinatesSafely() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeImpulseTexture(size: 9, alpha: 255)
        let coc = try makeSolidTexture(width: 3, height: 2, value: 255)

        let output = try HarbethIO(
            element: input,
            filter: C7HexagonalBokehBlur(radius: 4, cocTexture: coc)
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(output.width, input.width)
        XCTAssertEqual(output.height, input.height)
        XCTAssertLessThan(pixel(output, x: 4, y: 4)[0], 255)
    }

    private func makeImpulseTexture(size: Int, alpha: UInt8) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: size,
            height: size,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "hexagonal-bokeh-impulse"
        )
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for index in stride(from: 3, to: bytes.count, by: 4) {
            bytes[index] = alpha
        }
        let center = (size / 2 * size + size / 2) * 4
        bytes[center] = alpha
        bytes[center + 1] = alpha
        bytes[center + 2] = alpha
        texture.replace(
            region: MTLRegionMake2D(0, 0, size, size),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: size * 4
        )
        return texture
    }

    private func makeSolidTexture(size: Int, value: UInt8) throws -> MTLTexture {
        try makeSolidTexture(width: size, height: size, value: value)
    }

    private func makeSolidTexture(width: Int, height: Int, value: UInt8) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "hexagonal-bokeh-coc"
        )
        let pixel = [value, value, value, 255] as [UInt8]
        let bytes = Array(repeating: pixel, count: width * height).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func pixel(_ texture: MTLTexture, x: Int, y: Int) -> [UInt8] {
        var value = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&value, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        return value
    }

    private func readPixels(_ texture: MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: texture.width * 4,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        return bytes
    }
}
