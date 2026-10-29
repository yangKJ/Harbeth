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

    func testLocalToneSignedAmountIdentityUniformAndExtendedRange() throws {
        let source = try localTexture(
            width: 5,
            height: 1,
            values: [
                0.25, 0.25, 0.25, 1, 0.25, 0.25, 0.25, 1,
                0, 0, 0, 0, 1.5, 0.5, 0.25, 1, 0.125, 0.125, 0.125, 0.5
            ]
        )
        for amount: Float in [-1, 0, 1] {
            let result = try HarbethIO(
                element: source,
                filter: C7LocalTone(amount: amount, tileGridSize: .init(columns: 1, rows: 1))
            ).output()
            let actual = localPixels(result)
            for (a, b) in zip(actual, localPixels(source)) { XCTAssertEqual(a, b, accuracy: 0.00001) }
        }
        XCTAssertThrowsError(try C7LocalTone(amount: .nan).validate())
        XCTAssertThrowsError(try C7LocalLaplacian(rangeSigma: 0).validate())
    }

    func testLocalToneNegativeAmountChangesLocalContrastAndPreservesAlpha() throws {
        let values = (0..<64).flatMap { index -> [Float] in
            let value = Float(index % 8) / 28 + 0.2
            return [value * 0.5, value * 0.5, value * 0.5, 0.5]
        }
        let source = try localTexture(width: 8, height: 8, values: values)
        let result = try HarbethIO(
            element: source,
            filter: C7LocalTone(amount: -0.8, tileGridSize: .init(columns: 1, rows: 1))
        ).output()
        let actual = localPixels(result)
        XCTAssertTrue(zip(actual, localPixels(source)).contains { abs($0 - $1) > 0.002 })
        for index in stride(from: 3, to: actual.count, by: 4) { XCTAssertEqual(actual[index], 0.5) }
        XCTAssertTrue(actual.allSatisfy { $0.isFinite && (0...0.5).contains($0) })
    }

    func testPreparedLocalStatisticsMatchWholeImageAcrossOddTiles() throws {
        let width = 29, height = 19
        let values = (0..<(width * height)).flatMap { index -> [Float] in
            let v = Float((index * 13) % 71) / 100 + 0.1
            return [v, v * 0.8, v * 0.6, 1]
        }
        let source = try localTexture(width: width, height: height, values: values)
        let whole = try HarbethIO(
            element: source,
            filter: C7LocalTone(amount: -0.7, tileGridSize: .init(columns: 4, rows: 3))
        ).output()
        let statistics = try LocalToneStatistics(
            device: source.device,
            width: width,
            height: height,
            clipLimit: 2,
            grid: .init(columns: 4, rows: 3)
        )
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        try statistics.encodeClear(commandBuffer: command)
        var tiles: [(Int, Int, MTLTexture)] = []
        for y in stride(from: 0, to: height, by: 7) {
            for x in stride(from: 0, to: width, by: 11) {
                let w = min(11, width - x), h = min(7, height - y)
                var pixels: [Float] = []
                for row in 0..<h {
                    let start = ((y + row) * width + x) * 4
                    pixels.append(contentsOf: values[start..<(start + w * 4)])
                }
                let input = try localTexture(width: w, height: h, values: pixels)
                tiles.append((x, y, input))
                try statistics.encodeAccumulate(source: input, origin: SIMD2(UInt32(x), UInt32(y)), commandBuffer: command)
            }
        }
        try statistics.encodePrepare(commandBuffer: command)
        let outputs = try tiles.map { tile -> MTLTexture in
            let output = try localTexture(
                width: tile.2.width,
                height: tile.2.height,
                values: Array(repeating: 0, count: tile.2.width * tile.2.height * 4)
            )
            try statistics.encodeApply(
                source: tile.2,
                destination: output,
                origin: SIMD2(UInt32(tile.0), UInt32(tile.1)),
                amount: -0.7,
                commandBuffer: command
            )
            return output
        }
        try command.commitAndWaitUntilCompleted(identifier: "local-tone-tile-test")
        let expected = localPixels(whole)
        for (tile, output) in zip(tiles, outputs) {
            let actual = localPixels(output)
            for y in 0..<output.height {
                for x in 0..<output.width {
                    for channel in 0..<4 {
                        XCTAssertEqual(
                            actual[(y * output.width + x) * 4 + channel],
                            expected[((y + tile.1) * width + x + tile.0) * 4 + channel],
                            accuracy: 0.00001
                        )
                    }
                }
            }
        }
    }

    func testLocalLaplacianMatchesIndependentCPUReferenceForGradientStepAndDarkNoise() throws {
        let width = 17, height = 13
        for pattern in 0..<3 {
            let gray = (0..<(width * height)).map { index -> Float in
                let x = index % width, y = index / width
                switch pattern {
                case 0: return 0.1 + Float(x + y) / 40
                case 1: return (x < 8 ? 0.2 : 0.8) + Float(y % 3) * 0.01
                default:
                    // 固定整数散列覆盖暗部噪声，避免每次运行改变输入。
                    let noise = UInt32(index + 17) &* 1_664_525 &+ 1_013_904_223
                    return 0.04 + Float((noise >> 8) & 255) / 255 * 0.025
                }
            }
            let source = try localTexture(width: width, height: height, values: gray.flatMap { [$0, $0, $0, 1] })
            let sourcePixels = localPixels(source)
            let quantized = stride(from: 0, to: gray.count * 4, by: 4).map { sourcePixels[$0] }
            for detail: Float in [-0.5, 1] {
                let expected = LocalLaplacianReference.process(quantized, width: width, height: height, detail: detail)
                let result = try HarbethIO(element: source, filter: C7LocalLaplacian(detail: detail)).output()
                let actual = localPixels(result)
                for index in gray.indices {
                    XCTAssertEqual(actual[index * 4], expected[index], accuracy: 0.0012, "像素\(index)，图案\(pattern)")
                    XCTAssertEqual(actual[index * 4 + 3], 1)
                }
            }
        }
    }

    func testLocalLaplacianConstantColorSurvivesCoverageAndSmallPyramids() throws {
        for (width, height) in [(1, 1), (5, 3), (17, 13)] {
            let values = (0..<(width * height)).flatMap { index -> [Float] in
                let alpha: Float = index % 5 == 0 ? 0 : (index % 2 == 0 ? 0.5 : 1)
                return [0.25 * alpha, 0.5 * alpha, 0.125 * alpha, alpha]
            }
            let source = try localTexture(width: width, height: height, values: values)
            let result = try HarbethIO(element: source, filter: C7LocalLaplacian()).output()
            for (a, b) in zip(localPixels(result), localPixels(source)) {
                XCTAssertEqual(a, b, accuracy: 0.001)
            }
        }
    }

    func testLocalLaplacianZeroAndTransparentExtendedPixelsAreIdentity() throws {
        let source = try localTexture(
            width: 4,
            height: 1,
            values: [0, 0, 0, 0, 0.2, 0.2, 0.2, 0.5, 1.5, 0.5, 0.25, 1, 0.4, 0.4, 0.4, 1]
        )
        let expected = localPixels(source)
        for filter in [C7LocalLaplacian(detail: 0), C7LocalLaplacian(intensity: 0)] {
            let result = try HarbethIO(element: source, filter: filter).output()
            XCTAssertEqual(localPixels(result), expected)
        }
        let result = localPixels(try HarbethIO(element: source, filter: C7LocalLaplacian()).output())
        for index in [0, 1, 2, 3, 7, 8, 9, 10, 11, 15] { XCTAssertEqual(result[index], expected[index]) }
    }

    private func localTexture(width: Int, height: Int, values: [Float]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let half = values.map(Float16.init)
        half.withUnsafeBytes {
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: $0.baseAddress!,
                bytesPerRow: width * 8
            )
        }
        return texture
    }

    private func localPixels(_ texture: MTLTexture) -> [Float] {
        var pixels = Array(repeating: Float16(0), count: texture.width * texture.height * 4)
        pixels.withUnsafeMutableBytes {
            texture.getBytes(
                $0.baseAddress!,
                bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0
            )
        }
        return pixels.map(Float.init)
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

/// 不依赖生产模块的 CPU Local Laplacian 数学参考实现。
private enum LocalLaplacianReference {
    private static let binomial: [Float] = [1, 4, 6, 4, 1]

    static func process(
        _ input: [Float],
        width: Int,
        height: Int,
        detail: Float,
        sigma: Float = 0.15,
        samples: Int = 8,
        levels: Int = 6
    ) -> [Float] {
        precondition(width > 0 && height > 0 && input.count == width * height)
        precondition(samples >= 2 && levels >= 1 && sigma > 0)

        let source = input.map { clamp($0, lower: 0, upper: 1) }
        let sourcePyramid = gaussianPyramid(source, width: width, height: height, maxLevels: levels)
        var result = Array(repeating: Float(0), count: input.count)

        for sampleIndex in 0..<samples {
            let reference = Float(sampleIndex) / Float(samples - 1)
            let remapped = source.map { remap($0, reference: reference, detail: detail, sigma: sigma) }
            let pyramid = gaussianPyramid(remapped, width: width, height: height, maxLevels: levels)
            let laplacians = laplacianPyramid(pyramid)
            let coarsest = pyramid.count - 1
            let coarseWeight = interpolationWeight(
                sourcePyramid[coarsest].pixels,
                reference: reference,
                samples: samples
            )
            var reconstruction = zip(sourcePyramid[coarsest].pixels.indices, sourcePyramid[coarsest].pixels)
                .map { index, value in value * coarseWeight[index] }
            var reconstructionWidth = sourcePyramid[coarsest].width
            var reconstructionHeight = sourcePyramid[coarsest].height

            for level in stride(from: laplacians.count - 1, through: 0, by: -1) {
                let parent = pyramid[level]
                let weight = interpolationWeight(
                    sourcePyramid[level].pixels,
                    reference: reference,
                    samples: samples
                )
                let expanded = expand(
                    reconstruction,
                    width: reconstructionWidth,
                    height: reconstructionHeight,
                    targetWidth: parent.width,
                    targetHeight: parent.height
                )
                reconstruction = zip(expanded.indices, expanded).map { index, value in
                    value + laplacians[level].pixels[index] * weight[index]
                }
                reconstructionWidth = parent.width
                reconstructionHeight = parent.height
            }

            for index in result.indices {
                result[index] += reconstruction[index]
            }
        }

        return result.map { clamp($0, lower: 0, upper: 1) }
    }

    /// 小而确定性的回归检查草稿，可被 XCTest 直接包装为 XCTAssertTrue。
    static func expectationChecks() -> [String: Bool] {
        let gradient = (0..<64).map { Float($0) / 63 }
        let staircase = (0..<64).map { ($0 % 8 < 4) ? Float(0.15) : Float(0.85) }
        let identity = process(gradient, width: 8, height: 8, detail: 0)
        let enhanced = process(staircase, width: 8, height: 8, detail: 1)
        return [
            "detail0 identity": zip(identity, gradient).allSatisfy { abs($0 - $1) < 0.000001 },
            "gradient shape": identity.count == 64 && identity.first == 0 && identity.last == 1,
            "staircase finite": enhanced.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 },
            "staircase changes": zip(enhanced, staircase).contains { abs($0 - $1) > 0.000001 }
        ]
    }

    private struct Level {
        let pixels: [Float]
        let width: Int
        let height: Int
    }

    private static func gaussianPyramid(_ image: [Float], width: Int, height: Int, maxLevels: Int) -> [Level] {
        var pyramid = [Level(pixels: image, width: width, height: height)]
        while pyramid.count < maxLevels {
            let previous = pyramid[pyramid.count - 1]
            if previous.width == 1 && previous.height == 1 { break }
            let nextWidth = max(1, (previous.width + 1) / 2)
            let nextHeight = max(1, (previous.height + 1) / 2)
            pyramid.append(
                Level(
                    pixels: reduce(previous.pixels, width: previous.width, height: previous.height),
                    width: nextWidth,
                    height: nextHeight
                )
            )
        }
        return pyramid
    }

    private static func reduce(_ image: [Float], width: Int, height: Int) -> [Float] {
        let targetWidth = max(1, (width + 1) / 2)
        let targetHeight = max(1, (height + 1) / 2)
        return (0..<targetHeight).flatMap { y in
            (0..<targetWidth).map { x in
                var value: Float = 0
                for ky in 0..<5 {
                    for kx in 0..<5 {
                        let sourceX = clamp(x * 2 + kx - 2, lower: 0, upper: width - 1)
                        let sourceY = clamp(y * 2 + ky - 2, lower: 0, upper: height - 1)
                        value += image[sourceY * width + sourceX] * binomial[kx] * binomial[ky] / 256
                    }
                }
                return value
            }
        }
    }

    private static func expand(_ image: [Float], width: Int, height: Int, targetWidth: Int, targetHeight: Int) -> [Float] {
        (0..<targetHeight).flatMap { y in
            (0..<targetWidth).map { x in
                let sourceX = Float(x) / 2
                let sourceY = Float(y) / 2
                let x0 = clamp(Int(sourceX.rounded(.down)), lower: 0, upper: width - 1)
                let y0 = clamp(Int(sourceY.rounded(.down)), lower: 0, upper: height - 1)
                let x1 = min(x0 + 1, width - 1)
                let y1 = min(y0 + 1, height - 1)
                let tx = sourceX - Float(x0)
                let ty = sourceY - Float(y0)
                let top = image[y0 * width + x0] * (1 - tx) + image[y0 * width + x1] * tx
                let bottom = image[y1 * width + x0] * (1 - tx) + image[y1 * width + x1] * tx
                return top * (1 - ty) + bottom * ty
            }
        }
    }

    private static func laplacianPyramid(_ pyramid: [Level]) -> [Level] {
        guard pyramid.count > 1 else { return [] }
        return (0..<(pyramid.count - 1)).map { index in
            let current = pyramid[index]
            let next = pyramid[index + 1]
            let expanded = expand(
                next.pixels,
                width: next.width,
                height: next.height,
                targetWidth: current.width,
                targetHeight: current.height
            )
            return Level(pixels: zip(current.pixels, expanded).map { $0 - $1 }, width: current.width, height: current.height)
        }
    }

    private static func remap(_ value: Float, reference: Float, detail: Float, sigma: Float) -> Float {
        let difference = value - reference
        return value + detail * difference * exp(-0.5 * difference * difference / (sigma * sigma))
    }

    private static func interpolationWeight(_ values: [Float], reference: Float, samples: Int) -> [Float] {
        values.map { value in
            max(0, 1 - abs(value - reference) * Float(samples - 1))
        }
    }

    private static func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T { min(max(value, lower), upper) }
}