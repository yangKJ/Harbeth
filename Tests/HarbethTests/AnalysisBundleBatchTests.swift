//
//  AnalysisBundleBatchTests.swift
//  Harbeth
//
//  由 Condy 创建于 2026/11/16。
//

import XCTest
import Metal
@testable import Harbeth

final class AnalysisBundleBatchTests: XCTestCase {
    func testCPUAndGPUArtifactsMatchForOddRGBA16FROI() throws {
        let texture = try makeTexture()
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(3, 2, 9, 7), valueRange: TextureAnalysisValueRange(minimum: 0, maximum: 2))
        let cpu = TextureAnalysisArtifacts.make(texture: texture, channel: .red, bins: 256, height: 7, scope: scope, preferredMethod: .cpuReadback)
        let gpu = TextureAnalysisArtifacts.make(texture: texture, channel: .red, bins: 256, height: 7, scope: scope, preferredMethod: .gpuMPS)
        XCTAssertEqual(cpu.statistics?.sampleCount, gpu.statistics?.sampleCount)
        XCTAssertEqual(cpu.statistics?.meanRed ?? 0, gpu.statistics?.meanRed ?? 0, accuracy: 1e-4)
        XCTAssertEqual(cpu.histogram?.bins, gpu.histogram?.bins)
        XCTAssertEqual(cpu.histogram?.totalSampleCount, gpu.histogram?.totalSampleCount)
        let a = try XCTUnwrap(cpu.histogramAttachment?.attachment.texture.c7.bytes())
        let b = try XCTUnwrap(gpu.histogramAttachment?.attachment.texture.c7.bytes())
        XCTAssertEqual(a.count, b.count)
        for (x, y) in zip(a, b) { XCTAssertLessThanOrEqual(abs(Int(x) - Int(y)), 1) }
    }

    func testGPUArtifactsHandleEmptyROIWithoutGPUSubmission() throws {
        let texture = try makeTexture()
        let monitor = HarbethContext.shared.performanceMonitor
        let old = HarbethContext.shared.enablePerformanceMonitor
        HarbethContext.shared.enablePerformanceMonitor = true
        monitor.clearAllMetrics()
        defer { HarbethContext.shared.enablePerformanceMonitor = old }
        let before = monitor.gpuWorkSnapshot().commandBufferCount
        let result = TextureAnalysisArtifacts.make(texture: texture, channel: .luminance, bins: 3, height: 7, scope: TextureAnalysisScope(region: MTLRegionMake2D(99, 99, 2, 2)), preferredMethod: .gpuMPS)
        XCTAssertEqual(result.statistics?.sampleCount ?? 0, 0)
        XCTAssertEqual(result.histogram?.totalSampleCount ?? 0, 0)
        XCTAssertEqual(monitor.gpuWorkSnapshot().commandBufferCount, before)
    }

    func testMaskedBundleSharesOneSubmissionAndMatchesCPUForAllChannels() throws {
        let texture = try makeTexture()
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 3, height: 5, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let mask = try XCTUnwrap(texture.device.makeTexture(descriptor: d))
        var maskBytes = [UInt8](repeating: 255, count: 3 * 5 * 4)
        for pixel in 0..<15 { maskBytes[pixel * 4] = pixel.isMultiple(of: 2) ? 255 : 0 }
        maskBytes.withUnsafeBytes { mask.replace(region: MTLRegionMake2D(0,0,3,5), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 12) }
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(3,2,9,7),
            mask: MaskDescriptor(texture: mask, component: .red, invert: true, opacity: 0.75), coverageThreshold: 0.5)
        let previous = HarbethContext.shared.enablePerformanceMonitor
        HarbethContext.shared.enablePerformanceMonitor = true
        defer { HarbethContext.shared.enablePerformanceMonitor = previous }
        let monitor = HarbethContext.shared.performanceMonitor
        for channel in [TextureHistogramChannel.red, .green, .blue, .alpha, .luminance] {
            let cpu = TextureAnalysisArtifacts.make(texture: texture, channel: channel, bins: 257, height: 7, scope: scope, preferredMethod: .cpuReadback)
            let before = monitor.gpuWorkSnapshot().commandBufferCount
            let gpu = TextureAnalysisArtifacts.make(texture: texture, channel: channel, bins: 257, height: 7, scope: scope, preferredMethod: .gpuMPS)
            XCTAssertEqual(monitor.gpuWorkSnapshot().commandBufferCount - before, 1)
            let a = try XCTUnwrap(cpu.statistics), b = try XCTUnwrap(gpu.statistics)
            XCTAssertGreaterThan(b.sampleCount, 0)
            XCTAssertEqual(a.sampleCount, b.sampleCount)
            XCTAssertEqual(a.meanRed, b.meanRed, accuracy: 0.0001)
            XCTAssertEqual(a.meanAlpha, b.meanAlpha, accuracy: 0.0001)
            XCTAssertEqual(cpu.histogram?.bins, gpu.histogram?.bins)
            let left = try XCTUnwrap(cpu.histogramAttachment?.attachment.texture.c7.bytes())
            let right = try XCTUnwrap(gpu.histogramAttachment?.attachment.texture.c7.bytes())
            XCTAssertEqual(left, right)
        }
        // 请求之间不缓存可变 mask。上一请求完成后更新输入必须立即生效。
        let first = TextureAnalysisArtifacts.make(texture: texture, channel: .red, bins: 32, height: 7, scope: scope, preferredMethod: .gpuMPS)
        maskBytes = [UInt8](repeating: 0, count: maskBytes.count)
        maskBytes.withUnsafeBytes { mask.replace(region: MTLRegionMake2D(0,0,3,5), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 12) }
        let second = TextureAnalysisArtifacts.make(texture: texture, channel: .red, bins: 32, height: 7, scope: scope, preferredMethod: .gpuMPS)
        XCTAssertNotEqual(first.statistics?.sampleCount, second.statistics?.sampleCount)
        XCTAssertEqual(second.statistics?.sampleCount, 9 * 7)
    }

    func testConcurrentBundleRequestsKeepIndependentTemporaryLeases() throws {
        let texture = try makeTexture()
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: texture, component: .red), coverageThreshold: 0.5)
        let expected = TextureAnalysisArtifacts.make(texture: texture, channel: .red, bins: 256, height: 7, scope: scope, preferredMethod: .cpuReadback)
        let transfer = HarbethUncheckedTransfer(value: (texture, scope, expected.histogram?.bins, expected.statistics?.sampleCount))
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            let values = transfer.value
            let result = TextureAnalysisArtifacts.make(texture: values.0, channel: .red, bins: 256, height: 7, scope: values.1, preferredMethod: .gpuMPS)
            XCTAssertEqual(result.histogram?.bins, values.2)
            XCTAssertEqual(result.statistics?.sampleCount, values.3)
        }
    }

    private func makeTexture() throws -> MTLTexture {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 17, height: 13, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let t = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: d))
        var values = [UInt16](); values.reserveCapacity(17 * 13 * 4)
        for i in 0..<(17 * 13) { let v = Float16(Float(i % 5) / 4); values += [v.bitPattern, v.bitPattern, v.bitPattern, Float16(1).bitPattern] }
        values.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, 17, 13), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 17 * 8) }
        return t
    }
}
