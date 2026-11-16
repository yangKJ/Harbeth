//
//  ScopedHistogramReductionTests.swift
//  HarbethTests
//
//  由 Condy 创建于 2026/11/16。
//

import XCTest
import Metal
@testable import Harbeth

final class ScopedHistogramReductionTests: XCTestCase {
    func testGPUBinsMatchCPUAcrossBinCountsAndOddROI() throws {
        let texture = try makeTexture(width: 7, height: 5) { index in
            let v = Float((index * 13) % 101) / 100
            return SIMD4(v, 1 - v, v * 0.5, index % 6 == 0 ? 0 : 1)
        }
        let mask = try makeTexture(width: 5, height: 3) { index in SIMD4(index % 2 == 0 ? 1 : 0, 0, 0, 1) }
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(1, 1, 5, 3), mask: MaskDescriptor(texture: mask, component: .red),
            luminanceRange: TextureLuminanceRange(minimum: 0, maximum: 0.95),
            colorRange: TextureColorRange(hue: .init(minimum: 0.9, maximum: 0.1, wrapsAroundUnit: true)), valueRange: .normalized)
        for bins in [1, 3, 16, 32, 256, 257, 1024, 4096] {
            let gpu = try XCTUnwrap(GPUTextureAnalysis.histogram(texture, channel: .red, bins: bins, scope: scope))
            let cpu = try XCTUnwrap(texture.c7.makeHistogram(channel: .red, bins: bins, region: scope.region, mask: scope.mask,
                luminanceRange: scope.luminanceRange, colorRange: scope.colorRange, coverageThreshold: scope.coverageThreshold,
                valueRange: scope.valueRange, preferredMethod: .cpuReadback))
            XCTAssertEqual(gpu.totalSampleCount, cpu.totalSampleCount, "bins=\(bins)")
            XCTAssertEqual(gpu.bins, cpu.bins, "bins=\(bins)")
            XCTAssertEqual(gpu.bins.reduce(0, +), UInt32(gpu.totalSampleCount), "bins=\(bins)")
        }
    }

    func testScopedHistogramRejectsNaNSelectedValue() throws {
        let texture = try makeTexture(width: 3, height: 3) { _ in SIMD4(Float.nan, 0, 0, 1) }
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(1, 1, 2, 2))
        XCTAssertNil(GPUTextureAnalysis.histogram(texture, channel: .red, bins: 256, scope: scope))
    }

    func testScopedHistogramPipelinesUseDynamicThreadgroupMemory() throws {
        for name in ["AnalysisScopedHistogram", "AnalysisScopedHistogramSIMD"] {
            let pipeline = try Compute.makeComputePipelineState(with: name)
            XCTAssertEqual(pipeline.staticThreadgroupMemoryLength, 0, name)
            XCTAssertGreaterThan(pipeline.maxTotalThreadsPerThreadgroup, 0, name)
        }
    }

    func testUnmaskedUniformAndVariedHistogramsConserveEverySample() throws {
        for flat in [true, false] {
            let source = try makeTexture(width: 65, height: 17) { index in
                let value: Float = flat ? 0.5 : Float((index * 13) % 19) / 4 - 1
                return SIMD4(value, value * 0.5, 0.25, index % 5 == 0 ? 0 : 1)
            }
            let scope = TextureAnalysisScope(valueRange: .init(minimum: -1, maximum: 4))
            for bins in [1, 3, 16, 32, 256, 257, 1024, 4096] {
                for channel in [TextureHistogramChannel.red, .luminance, .alpha] {
                    let gpu = try XCTUnwrap(GPUTextureAnalysis.histogram(source, channel: channel, bins: bins, scope: scope))
                    let cpu = try XCTUnwrap(source.c7.makeHistogram(channel: channel, bins: bins, scope: scope, preferredMethod: .cpuReadback))
                    XCTAssertEqual(gpu.bins, cpu.bins, "bins=\(bins), channel=\(channel)")
                    XCTAssertEqual(gpu.totalSampleCount, 65 * 17)
                }
            }
        }
    }

    func testIntegerFallbackAndSIMDReductionAgreeForNonPowerOfTwoBins() throws {
        let source = try makeTexture(width: 65, height: 17) { i in SIMD4(Float(i % 251) / 250, 0.25, 0.5, 1) }
        var outputs: [[UInt32]] = []
        let device = source.device
        for name in ["AnalysisScopedHistogram", "AnalysisScopedHistogramSIMD"] {
            if name.hasSuffix("SIMD") && !(device.supportsFamily(.apple7) || device.supportsFamily(.mac2)) { continue }
            let pipeline = try Compute.makeComputePipelineState(with: name)
            let result = try XCTUnwrap(device.makeBuffer(length: 259 * 4, options: .storageModeShared))
            memset(result.contents(), 0, result.length)
            let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
            let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
            var p: [Float] = [0,0,65,17,0,0,0.5,0,0,1, 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,1,1,257,Float(pipeline.threadExecutionWidth)]
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(source, index: 0); encoder.setTexture(source, index: 1)
            encoder.setBuffer(result, offset: 0, index: 0); encoder.setBytes(&p, length: p.count * 4, index: 1)
            encoder.setThreadgroupMemoryLength((257 * 4 + 15) & ~15, index: 0)
            encoder.dispatchThreadgroups(MTLSize(width: (65 * 17 + 255) / 256, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
            encoder.endEncoding()
            try command.commitAndWaitUntilCompleted(identifier: name)
            outputs.append(Array(UnsafeBufferPointer(start: result.contents().bindMemory(to: UInt32.self, capacity: 259), count: 259)))
            XCTAssertEqual(outputs.last?[257], 65 * 17)
            XCTAssertEqual(outputs.last?[258], 0)
        }
        for output in outputs { XCTAssertEqual(output, outputs[0]) }
    }

    private func makeTexture(width: Int, height: Int, _ value: (Int) -> SIMD4<Float>) throws -> MTLTexture {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        var values = (0..<(width * height)).map(value)
        values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * MemoryLayout<SIMD4<Float>>.stride) }
        return texture
    }
}
