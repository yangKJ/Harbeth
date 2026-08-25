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
        HarbethContext.shared.claheTemporaryBufferPool.resetForTesting()
        defer { HarbethContext.shared.claheTemporaryBufferPool.resetForTesting() }

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

        let statistics = HarbethContext.shared.claheTemporaryBufferPool.statistics
        let p95Index = Int(ceil(Double(elapsedTimes.count) * 0.95)) - 1
        let p95 = elapsedTimes.sorted()[p95Index]

        XCTAssertEqual(C7CLAHE.commandEncoderCount, 4, "CLAHE must keep one clear, histogram, LUT and apply encoder.")
        XCTAssertEqual(statistics.totalBufferAllocations, 3, "4K hot renders must not allocate another CLAHE buffer set.")
        XCTAssertEqual(statistics.totalBufferReuses, 12)
        XCTAssertEqual(statistics.peakInFlightSetCount, 1)
        XCTAssertEqual(statistics.cachedSetCount, 1)
        XCTAssertLessThan(p95, 1.0, "4K CLAHE hot-path p95 must stay below the one-second regression gate.")
    }

    func testTemporaryBuffersCanRecycleAfterRecovery() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable in this environment.")
        }
        let context = HarbethContext.shared
        context.recoverExecution()
        let pool = context.claheTemporaryBufferPool
        pool.resetForTesting()
        defer {
            pool.resetForTesting()
            context.recoverExecution()
        }

        let buffers = try pool.checkout(device: device, histogramLength: 256, countLength: 4, lookupLength: 1_024)
        XCTAssertEqual(pool.statistics.totalBufferAllocations, 3)
        XCTAssertEqual(pool.statistics.cachedSetCount, 0, "仍在执行的 buffer 不得作为可复用缓存暴露。")
        XCTAssertEqual(pool.statistics.peakInFlightSetCount, 1)

        // Recovery 会清理 Context 的 transient registry，但已提交 command buffer 的完成回调仍可能稍后执行。
        context.recoverExecution()
        XCTAssertEqual(pool.statistics.cachedSetCount, 0, "Recovery 不得让仍在执行的 buffer 提前可复用。")

        // 模拟完成回调仍持有原始 pool。
        pool.recycle(buffers)
        XCTAssertEqual(pool.statistics.cachedSetCount, 1)

        let reused = try pool.checkout(device: device, histogramLength: 256, countLength: 4, lookupLength: 1_024)
        let statistics = pool.statistics
        XCTAssertEqual(statistics.totalBufferAllocations, 3)
        XCTAssertEqual(statistics.totalBufferReuses, 3)
        pool.recycle(reused)
    }

    func testConcurrentCheckoutsKeepDistinctInFlightSetsAndBoundIdleCapacity() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable in this environment.")
        }
        let pool = CLAHETemporaryBufferPool()

        let collector = BufferSetCollector()
        DispatchQueue.concurrentPerform(iterations: 4) { _ in
            do {
                collector.append(
                    try pool.checkout(device: device, histogramLength: 256, countLength: 4, lookupLength: 1_024)
                )
            } catch {
                collector.record(error)
            }
        }

        XCTAssertNil(collector.error)
        XCTAssertEqual(collector.bufferSets.count, 4)
        XCTAssertEqual(pool.statistics.totalBufferAllocations, 12)
        XCTAssertEqual(pool.statistics.peakInFlightSetCount, 4)
        XCTAssertEqual(pool.statistics.cachedSetCount, 0)

        collector.bufferSets.forEach(pool.recycle)
        XCTAssertEqual(pool.statistics.cachedSetCount, 2, "空闲容量必须遵守全局两组上限。")
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
        _ = try filter.applyAtTexture(form: source, to: destination, for: commandBuffer)
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

private final class BufferSetCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var sets: [CLAHETemporaryBufferPool.BufferSet] = []
    private var storedError: Error?

    func append(_ bufferSet: CLAHETemporaryBufferPool.BufferSet) {
        lock.lock()
        sets.append(bufferSet)
        lock.unlock()
    }

    func record(_ error: Error) {
        lock.lock()
        storedError = error
        lock.unlock()
    }

    var bufferSets: [CLAHETemporaryBufferPool.BufferSet] {
        lock.lock()
        defer { lock.unlock() }
        return sets
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }
}
