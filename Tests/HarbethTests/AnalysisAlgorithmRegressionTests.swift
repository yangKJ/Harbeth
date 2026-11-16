//
//  AnalysisAlgorithmRegressionTests.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class AnalysisAlgorithmRegressionTests: XCTestCase {
    func testGPUStatistics4KConstantR32HasStableMean() throws {
        let texture = try makeR32Texture(width: 3840, height: 2160, value: 0.1)
        let result = try XCTUnwrap(GPUTextureAnalysis.statistics(texture, scope: TextureAnalysisScope()))
        XCTAssertEqual(result.sampleCount, 3840 * 2160)
        XCTAssertEqual(result.meanRed, 0.1, accuracy: 1e-6)
        XCTAssertEqual(result.meanGreen, 0.1, accuracy: 1e-6)
        XCTAssertEqual(result.meanBlue, 0.1, accuracy: 1e-6)
    }

    func testSmallGPUStatisticsMatchesCPUReference() throws {
        let texture = try makeFloatTexture(width: 4, height: 2) { index in
            let value = Float(index + 1) / 10
            return SIMD4(value, value * 2, 1 - value, 1)
        }
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(1, 0, 2, 2))
        let gpu = try XCTUnwrap(GPUTextureAnalysis.statistics(texture, scope: scope))
        let cpu = try XCTUnwrap(texture.c7.makeStatistics(region: scope.region))
        XCTAssertEqual(gpu.sampleCount, cpu.sampleCount)
        XCTAssertEqual(gpu.meanRed, cpu.meanRed, accuracy: 1e-5)
        XCTAssertEqual(gpu.meanGreen, cpu.meanGreen, accuracy: 1e-5)
        XCTAssertEqual(gpu.meanBlue, cpu.meanBlue, accuracy: 1e-5)
        XCTAssertEqual(gpu.meanLuminance, cpu.meanLuminance, accuracy: 1e-5)
    }

    func test4KWeightedColorHistogramPreservesPixelBudget() throws {
        let texture = try makeRGBA8Texture(width: 3840, height: 2160, value: [26, 51, 77, 255])
        let histogram = try texture.c7.makeWeightedColorHistogram()
        let expected = Double(3840 * 2160)
        for (index, channel) in histogram.channels.enumerated() {
            XCTAssertEqual(channel.reduce(0, +), expected, accuracy: expected * 1e-5)
            let expectedBin = [26, 51, 77][index]
            XCTAssertEqual(channel[expectedBin], expected, accuracy: expected * 1e-5)
            XCTAssertEqual(channel.enumerated().filter { $0.offset != expectedBin }.reduce(0) { $0 + $1.element }, 0, accuracy: expected * 1e-5)
        }
    }

    func testGPUHistogramSupportsRegionMaskRangesAndHueWrap() throws {
        let texture = try makeFloatTexture(width: 4, height: 2) { index in
            let colors: [SIMD4<Float>] = [SIMD4(1, 0, 0, 1), SIMD4(0, 1, 0, 1), SIMD4(0, 0, 1, 1), SIMD4(1, 1, 1, 1), SIMD4(0.2, 0.2, 0.2, 1), SIMD4(0.8, 0.1, 0.1, 1), SIMD4(0.1, 0.8, 0.1, 1), SIMD4(0.1, 0.1, 0.8, 1)]
            return colors[index]
        }
        let mask = try makeFloatTexture(width: 4, height: 2) { index in SIMD4(index.isMultiple(of: 2) ? 1 : 0, 0, 0, 1) }
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(0, 0, 4, 2), mask: MaskDescriptor(texture: mask, component: .red), luminanceRange: TextureLuminanceRange(minimum: 0, maximum: 1), colorRange: TextureColorRange(hue: .init(minimum: 0.9, maximum: 0.1, wrapsAroundUnit: true)), valueRange: TextureAnalysisValueRange(minimum: 0, maximum: 4))
        let histogram = try XCTUnwrap(GPUTextureAnalysis.histogram(texture, channel: .red, bins: 16, scope: scope))
        XCTAssertGreaterThan(histogram.totalSampleCount, 0)
        XCTAssertEqual(Int(histogram.bins.reduce(0, +)), histogram.totalSampleCount)
    }

    func testGPUScopedMaskPreservesPixelAndAlpha() throws {
        let texture = try makeFloatTexture(width: 2, height: 2) { _ in SIMD4(0.25, 0.5, 0.75, 0.4) }
        let mask = try makeFloatTexture(width: 2, height: 2) { index in SIMD4(index == 0 ? 1 : 0, 0, 0, 1) }
        let output = try XCTUnwrap(try GPUTextureAnalysis.mask(texture, scope: TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red)), pixelFormat: .rgba32Float))
        var values = [Float](repeating: 0, count: 16)
        output.getBytes(&values, bytesPerRow: 2 * 16, from: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0)
        for (actual, expected) in zip(values[0..<4], [Float(1), 1, 1, 1]) { XCTAssertEqual(actual, expected, accuracy: Float(1e-5)) }
        for (actual, expected) in zip(values[4..<8], [Float(0), 0, 0, 1]) { XCTAssertEqual(actual, expected, accuracy: Float(1e-5)) }
    }

    func testOptionalAnalysisBenchmark() throws {
        guard ProcessInfo.processInfo.environment["HARBETH_ALGORITHM_BENCHMARKS"] == "1" else { throw XCTSkip("Set HARBETH_ALGORITHM_BENCHMARKS=1") }
        let texture = try makeR32Texture(width: 3840, height: 2160, value: 0.1)
        let start = CFAbsoluteTimeGetCurrent(); _ = GPUTextureAnalysis.statistics(texture, scope: TextureAnalysisScope()); let elapsed = CFAbsoluteTimeGetCurrent() - start
        let configuration = ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "unknown"
        print("HARBETH_ALGORITHM_BENCHMARKS device=\(texture.device.name) configuration=\(configuration) statistics4K=\(elapsed)s")
    }

    private func makeFloatTexture(width: Int, height: Int, value: (Int) -> SIMD4<Float>) throws -> MTLTexture {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        var values = [SIMD4<Float>](); values.reserveCapacity(width * height)
        for index in 0..<(width * height) { values.append(value(index)) }
        values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * MemoryLayout<SIMD4<Float>>.stride) }
        return texture
    }

    private func makeR32Texture(width: Int, height: Int, value: Float) throws -> MTLTexture {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        var values = [Float](repeating: value, count: width * height)
        values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * MemoryLayout<Float>.stride) }
        return texture
    }

    private func makeRGBA8Texture(width: Int, height: Int, value: [UInt8]) throws -> MTLTexture {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for offset in stride(from: 0, to: bytes.count, by: 4) { bytes.replaceSubrange(offset..<(offset + 4), with: value) }
        bytes.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        return texture
    }
}
