//
//  CLAHEFilterTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/5.
//

import Metal
import XCTest
@testable import Harbeth

final class CLAHEFilterTests: XCTestCase {

    func testPublicParametersAndPixelContract() {
        let filter = C7CLAHE(
            clipLimit: 100,
            tileGridSize: .init(columns: -4, rows: 100)
        )

        XCTAssertEqual(filter.clipLimit, C7CLAHE.clipLimitRange.max)
        XCTAssertEqual(filter.tileGridSize.columns, C7CLAHE.TileGridSize.minimumDimension)
        XCTAssertEqual(filter.tileGridSize.rows, C7CLAHE.TileGridSize.maximumDimension)
        XCTAssertEqual(filter.kernelPixelContract.inputAlphaExpectation, .premultiplied)
        XCTAssertEqual(filter.kernelPixelContract.outputAlpha, .premultiplied)
        XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .global)
        XCTAssertEqual(filter.kernelPixelContract.globalDependency, .imageStatistics)
    }

    func testUniformSDRInputRemainsStable() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let source = try makeRGBA8Texture(
            width: 4,
            height: 4,
            pixel: [96, 96, 96, 255]
        )

        let output = try HarbethIO(
            element: source,
            filter: C7CLAHE(clipLimit: 2, tileGridSize: .init(columns: 2, rows: 2))
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(readRGBA8(output, x: 0, y: 0), [96, 96, 96, 255])
        XCTAssertEqual(readRGBA8(output, x: 3, y: 3), [96, 96, 96, 255])
    }

    func testLocalLookupExpandsDarkToBrightSDRRangeAndPreservesAlpha() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let source = try makeRGBA8Texture(
            width: 4,
            height: 1,
            pixels: [
                32, 16, 8, 128,
                64, 32, 16, 128,
                96, 48, 24, 128,
                128, 64, 32, 128
            ]
        )

        let output = try HarbethIO(
            element: source,
            filter: C7CLAHE(clipLimit: 16, tileGridSize: .init(columns: 1, rows: 1))
        ).renderTexture(profile: .stablePreview)

        let first = readRGBA8(output, x: 0, y: 0)
        let last = readRGBA8(output, x: 3, y: 0)
        XCTAssertEqual(first[3], 128)
        XCTAssertEqual(last[3], 128)
        XCTAssertLessThan(first[0], 32)
        XCTAssertGreaterThan(last[0], 120)
        XCTAssertLessThanOrEqual(first[0], first[3])
        XCTAssertLessThanOrEqual(last[0], last[3])
    }

    func testTransparentAndExtendedRangePixelsRemainUntouched() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let source = try makeRGBA16FloatTexture(
            width: 2,
            pixels: [
                0, 0, 0, 0,
                1.5, 0.5, 0.25, 1
            ]
        )

        let output = try HarbethIO(
            element: source,
            filter: C7CLAHE(tileGridSize: .init(columns: 1, rows: 1))
        ).renderTexture(profile: .stablePreview)
        let pixels = readRGBA16Float(output)

        XCTAssertEqual(pixels[0], 0, accuracy: 0.0001)
        XCTAssertEqual(pixels[3], 0, accuracy: 0.0001)
        XCTAssertEqual(pixels[4], 1.5, accuracy: 0.001)
        XCTAssertEqual(pixels[5], 0.5, accuracy: 0.001)
        XCTAssertEqual(pixels[6], 0.25, accuracy: 0.001)
        XCTAssertEqual(pixels[7], 1, accuracy: 0.0001)
    }

    func testOuterPixelsClampToNearestTileLookup() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let source = try makeRGBA8Texture(
            width: 4,
            height: 1,
            pixels: [
                128, 128, 128, 255,
                64, 64, 64, 255,
                32, 32, 32, 255,
                192, 192, 192, 255
            ]
        )

        let output = try HarbethIO(
            element: source,
            filter: C7CLAHE(clipLimit: 16, tileGridSize: .init(columns: 2, rows: 1))
        ).renderTexture(profile: .stablePreview)

        XCTAssertGreaterThan(readRGBA8(output, x: 0, y: 0)[0], 240)
    }

    func test4KHotPathReusesTemporaryBuffersWithinResourceAndPerformanceGate() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable in this environment.")
        }
        HarbethContext.shared.recoverExecution()
        C7CLAHETemporaryBufferPool.shared.resetForTesting()
        defer { C7CLAHETemporaryBufferPool.shared.resetForTesting() }

        let source = try makePrivateTexture(device: device, width: 3_840, height: 2_160)
        let destination = try makePrivateTexture(device: device, width: 3_840, height: 2_160)
        let filter = C7CLAHE(tileGridSize: .init(columns: 8, rows: 8))

        try render(filter, source: source, destination: destination, identifier: "CLAHE.4K.warmup")
        var elapsedTimes = [TimeInterval]()
        for index in 0..<4 {
            let start = Date()
            try render(filter, source: source, destination: destination, identifier: "CLAHE.4K.hot.\(index)")
            elapsedTimes.append(Date().timeIntervalSince(start))
        }

        let statistics = C7CLAHETemporaryBufferPool.shared.statistics
        let p95Index = Int(ceil(Double(elapsedTimes.count) * 0.95)) - 1
        let p95 = elapsedTimes.sorted()[p95Index]

        XCTAssertEqual(C7CLAHE.commandEncoderCount, 4, "CLAHE must keep one clear, histogram, LUT and apply encoder.")
        XCTAssertEqual(statistics.totalBufferAllocations, 3, "4K hot renders must not allocate another CLAHE buffer set.")
        XCTAssertEqual(statistics.totalBufferReuses, 12)
        XCTAssertEqual(statistics.peakInFlightSetCount, 1)
        XCTAssertEqual(statistics.cachedSetCount, 1)
        XCTAssertLessThan(p95, 1.0, "4K CLAHE hot-path p95 must stay below the one-second regression gate.")
    }

    private func makeRGBA8Texture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        try makeRGBA8Texture(width: width, height: height, pixels: Array(repeating: pixel, count: width * height).flatMap { $0 })
    }

    private func makeRGBA8Texture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "clahe-rgba8-input"
        )
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func makePrivateTexture(device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]
        return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
    }

    private func render(_ filter: C7CLAHE,
                        source: MTLTexture,
                        destination: MTLTexture,
                        identifier: String) throws {
        let commandBuffer = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        _ = try filter.encode(commandBuffer: commandBuffer, textures: [destination, source])
        try commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
    }

    private func makeRGBA16FloatTexture(width: Int, pixels: [Float16]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: 1,
            options: [.texturePixelFormat: MTLPixelFormat.rgba16Float],
            identifier: "clahe-rgba16f-input"
        )
        pixels.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, 1),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * 8
            )
        }
        return texture
    }

    private func readRGBA8(_ texture: MTLTexture, x: Int, y: Int) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &pixel,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return pixel
    }

    private func readRGBA16Float(_ texture: MTLTexture) -> [Float] {
        var pixels = [Float16](repeating: 0, count: texture.width * 4)
        pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, 1),
                mipmapLevel: 0
            )
        }
        return pixels.map(Float.init)
    }
}
