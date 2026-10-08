//
//  ArchitecturePerformanceTests.swift
//  Harbeth
//
//  Created by Condy on 2026/10/07.
//

import XCTest
import Metal
import Foundation
import QuartzCore
import Darwin
@testable import Harbeth

/// 🧪 架构路径基准：默认跳过，避免普通测试重复执行大型 Metal 工作负载。
final class ArchitecturePerformanceTests: XCTestCase {
    private let frameCount = 300
    private let warmupCount = 20
    private let sizes = [(name: "1080p", width: 1920, height: 1080), (name: "4K", width: 3840, height: 2160)]

    func testArchitectureRoutes() throws {
        guard let reportPath = ProcessInfo.processInfo.environment["HARBETH_ARCHITECTURE_REPORT"], !reportPath.isEmpty else {
            throw XCTSkip("设置 HARBETH_ARCHITECTURE_REPORT 后运行正式架构性能基准")
        }
        let context = HarbethContext.shared
        let previousMonitorState = context.enablePerformanceMonitor
        context.enablePerformanceMonitor = true
        var monitorConfiguration = PerformanceMonitor.Configuration()
        monitorConfiguration.enabled = true
        monitorConfiguration.logLevel = .error
        monitorConfiguration.maxStoredMetrics = 256
        context.performanceMonitor.configure(monitorConfiguration)
        defer {
            context.performanceMonitor.clearAllMetrics()
            context.enablePerformanceMonitor = previousMonitorState
        }
        var reports: [[String: Any]] = []
        for size in sizes {
            let texture = try makeTexture(width: size.width, height: size.height)
            reports.append(try measure(name: "filter-chain-makeTexture", size: size, texture: texture) { texture in
                let node = ImageNode.texture(texture)
                    .applying(C7Brightness(brightness: 0.04))
                    .applying(C7Contrast(contrast: 1.04))
                    .applying(C7Saturation(saturation: 1.03))
                _ = try node.makeTexture(profile: .stablePreview)
                return nil
            })
            reports.append(try measure(name: "filter-editing-makeFrame", size: size, texture: texture) { texture in
                let node = ImageNode.texture(texture)
                    .applying(C7Brightness(brightness: 0.04))
                    .editing(EditRecipe(geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: size.width - 2, height: size.height - 2), aspectPolicy: .fit)))
                let frame = try node.makeFrame(profile: .stablePreview)
                return frame.metadata["performanceMonitoringIdentifier"] ?? frame.identifier
            })
            let layer = try makeTexture(width: size.width, height: size.height, pixel: [220, 128, 64, 255])
            reports.append(try measure(name: "layer-composite-nearest-makeFrame", size: size, texture: texture) { texture in
                let filter = try RenderLayerComposite(
                    layerTexture: layer,
                    normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                    opacity: 0.9
                )
                let frame = try ImageNode.texture(texture).applying(filter).withSamplerDescriptor(.nearest)
                    .makeFrame(profile: .stablePreview)
                return frame.metadata["performanceMonitoringIdentifier"] ?? frame.identifier
            })
        }
        let object: [String: Any] = [
            "schema": "harbeth.architecture-performance.v1",
            "device": HarbethContext.shared.device.name,
            "frameCount": frameCount,
            "warmupCount": warmupCount,
            "pixelFormat": "rgba8Unorm",
            "reports": reports
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: reportPath), options: .atomic)
    }

    private func measure(
        name: String,
        size: (name: String, width: Int, height: Int),
        texture: MTLTexture,
        operation: (MTLTexture) throws -> String?
    ) throws -> [String: Any] {
        HarbethContext.shared.resetCaches()
        HarbethContext.shared.texturePool.purgeAllTexturesSync()
        let monitor = HarbethContext.shared.performanceMonitor
        let firstGPU = monitor.gpuWorkSnapshot()
        let firstStart = CACurrentMediaTime()
        _ = try autoreleasepool { try operation(texture) }
        let firstFrameMs = (CACurrentMediaTime() - firstStart) * 1_000
        let firstCommandBufferCount = monitor.gpuWorkSnapshot().commandBufferCount - firstGPU.commandBufferCount
        for _ in 0..<warmupCount { _ = try autoreleasepool { try operation(texture) } }
        var samples: [Double] = []
        var gpuSamples: [Double] = []
        var commandBufferCounts: [Int] = []
        var rssPeak = currentResidentMemory()
        samples.reserveCapacity(frameCount)
        for _ in 0..<frameCount {
            let gpuBefore = monitor.gpuWorkSnapshot()
            let start = CACurrentMediaTime()
            _ = try autoreleasepool { try operation(texture) }
            let elapsedMs = (CACurrentMediaTime() - start) * 1_000
            rssPeak = max(rssPeak, currentResidentMemory())
            let gpuAfter = monitor.gpuWorkSnapshot()
            let milliseconds = Double(gpuAfter.nanoseconds - gpuBefore.nanoseconds) / 1_000_000
            if milliseconds.isFinite, milliseconds > 0 { gpuSamples.append(milliseconds) }
            commandBufferCounts.append(gpuAfter.commandBufferCount - gpuBefore.commandBufferCount)
            samples.append(elapsedMs)
        }
        let sorted = samples.sorted()
        let average = samples.reduce(0, +) / Double(samples.count)
        let pool = HarbethContext.shared.texturePool.statistics
        return [
            "scenario": name,
            "size": size.name,
            "width": size.width,
            "height": size.height,
            "averageMs": average,
            "p95Ms": percentile(sorted, 0.95),
            "p99Ms": percentile(sorted, 0.99),
            "firstFrameMs": firstFrameMs,
            "gpuMs": gpuSamples.isEmpty ? NSNull() : gpuSamples.reduce(0, +) / Double(gpuSamples.count),
            "commandBufferCount": Double(commandBufferCounts.reduce(0, +)) / Double(frameCount),
            "firstCommandBufferCount": firstCommandBufferCount,
            "commandBufferCounts": commandBufferCounts,
            "gpuTimestampedFrames": gpuSamples.count,
            "metalCompilationCount": NSNull(),
            "rssPeakBytes": rssPeak == 0 ? NSNull() : rssPeak,
            "fieldScope": [
                "gpuMs": "每帧前后累计 GPU 完成时间差，覆盖同标识重启监控前的上游工作",
                "commandBufferCount": "每帧真实完成的 Harbeth command buffer 数量",
                "metalCompilationCount": "由独立 Render pipeline 并发创建测试记录，不以缓存 miss 推断",
                "rssPeakBytes": "帧间采样 resident_size 的最大值，不含采样间瞬时峰值"
            ],
            "texturePool": [
                "created": pool.totalTexturesCreated,
                "reused": pool.totalTexturesReused,
                "heapReservedBytes": pool.heapReservedMemory,
                "heapUsedBytes": pool.heapUsedMemory
            ]
        ]
    }

    private func currentResidentMemory() -> UInt64 {
        #if os(macOS) || os(iOS) || os(tvOS)
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutableBytes(of: &info) { bytes in
            bytes.withMemoryRebound(to: integer_t.self) { pointer in
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), pointer.baseAddress, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
        #else
        return 0
        #endif
    }

    private func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))
        return sorted[index]
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8] = [96, 128, 160, 255]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal device unavailable") }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw XCTSkip("Texture allocation failed") }
        let row = Array(repeating: pixel, count: width).flatMap { $0 }
        for y in 0..<height {
            texture.replace(region: MTLRegionMake2D(0, y, width, 1), mipmapLevel: 0, withBytes: row, bytesPerRow: width * 4)
        }
        return texture
    }
}
