//
//  ImageNodeObservabilityTests.swift
//  Harbeth
//
//  覆盖 ImageNode 直接路径的最小 observability 闭环：
//   - `makeFrame` 入口/出口的 `beginMonitoring` / `endMonitoring`
//   - 在 host decision 已知处的 `recordPreviewHostStrategy`
//   - 监控开关关闭时不调 record（零成本）
//
// 不覆盖：preview host enqueue / execution / fleet snapshot 等更细埋点
// （按 plan 第 4 节 Task C，保持最小闭环，不一次性把 HarbethIO 路径埋点全量搬过来）。
//

import XCTest
import Metal
@testable import Harbeth

final class ImageNodeObservabilityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Shared.shared.enablePerformanceMonitor = true
    }

    override func tearDown() {
        Shared.shared.enablePerformanceMonitor = false
        Shared.shared.performanceMonitor?.clearAllMetrics()
        super.tearDown()
    }

    // MARK: - 最小闭环 1/3: begin/end monitoring 在 `ImageNode.<nodeFingerprint>` identifier 上记录

    /// `makeFrame` 入口/出口应触发 `beginMonitoring` / `endMonitoring`，
    /// PerformanceMonitor 在 `ImageNode.<nodeFingerprint>` identifier 下记录 elapsed。
    func testMakeFrameRecordsBeginAndEndMonitoringOnImageNodeIdentifier() throws {
        let input = try makeSolidTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.2))

        let frame = try node.makeFrame()
        let monitoringIdentifier = frame.token.identifier

        // identifier 必须以 "ImageNode." 开头（与 makeFrame 内部的 nodeFingerprint 一致）
        XCTAssertTrue(monitoringIdentifier.hasPrefix("ImageNode."),
                      "FrameRenderToken.identifier should be ImageNode-prefixed, got \(monitoringIdentifier)")

        // PerformanceMonitor 必须在该 identifier 下记录 metrics
        let monitor = try XCTUnwrap(Shared.shared.performanceMonitor, "PerformanceMonitor must be enabled")
        let metrics = try XCTUnwrap(monitor.getMetrics(monitoringIdentifier),
                                    "Metrics should exist for \(monitoringIdentifier)")

        // beginMonitoring 已触发，startTime > 0；endMonitoring 已触发，endTime > 0
        XCTAssertGreaterThan(metrics.startTime, 0)
        XCTAssertGreaterThan(metrics.endTime, 0)
        XCTAssertGreaterThan(metrics.totalProcessingTime, 0)
        XCTAssertGreaterThan(metrics.gpuTotalTimeNanoseconds, 0,
                             "GPU time should be attributed to the ImageNode identifier instead of an internal UUID")
    }

    /// 不同 storage 的 node（filters / editing）共用同一个最小闭环路径，identifier 都应是 `ImageNode.*`。
    func testMakeFrameMonitoringIdentifierIsConsistentAcrossStorageVariants() throws {
        let input = try makeSolidTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])

        let filteredFrame = try ImageNode.texture(input)
            .applying(C7Brightness(brightness: 0.2))
            .makeFrame()
        let editingFrame = try ImageNode.texture(input)
            .editing(EditRecipe())
            .makeFrame()
        let recipeFrame = try ImageNode
            .recipe(source: .texture(input), recipe: EditRecipe())
            .makeFrame()

        XCTAssertTrue(filteredFrame.token.identifier.hasPrefix("ImageNode."))
        XCTAssertTrue(editingFrame.token.identifier.hasPrefix("ImageNode."))
        XCTAssertTrue(recipeFrame.token.identifier.hasPrefix("ImageNode."))

        // 不同 storage 应当产生不同的 identifier
        XCTAssertNotEqual(filteredFrame.token.identifier, editingFrame.token.identifier)
    }

    // MARK: - 最小闭环 2/3: recordPreviewHostStrategy 在 host decision 已知处调一次

    /// Texture source 的 node 渲染后，monitor 必须在 `ImageNode.*` identifier 下
    /// `previewHostMetalStrategyCount` 计数 +1（非 sampleBuffer source → .metalTextureHost）。
    func testMakeFrameRecordsMetalTextureHostStrategyForTextureSource() throws {
        let input = try makeSolidTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.2))

        let frame = try node.makeFrame()
        let monitor = try XCTUnwrap(Shared.shared.performanceMonitor, "PerformanceMonitor must be enabled")
        let metrics = try XCTUnwrap(monitor.getMetrics(frame.token.identifier),
                                    "Metrics should exist for \(frame.token.identifier)")

        // Texture source 应被识别为 metalTextureHost
        XCTAssertEqual(metrics.previewHostMetalStrategyCount, 1)
        XCTAssertEqual(metrics.previewHostPassthroughStrategyCount, 0)
        XCTAssertEqual(metrics.previewHostRematerializedStrategyCount, 0)

        // resourceEvents 应记录 strategy 决策
        XCTAssertTrue(
            metrics.resourceEvents.contains(where: { $0.contains("previewHostExecution:strategy:metalTextureHost") }),
            "Expected resourceEvents to contain metalTextureHost strategy event, got: \(metrics.resourceEvents)"
        )
    }

    // MARK: - 最小闭环 3/3: monitor 关闭时 record 调用为 no-op，不影响渲染

    /// 当 `enablePerformanceMonitor = false` 时，`Shared.shared.performanceMonitor` 为 nil，
    /// `ImageNode.makeFrame` 内的 monitor 路径全部走 nil-conditional 短路，
    /// 渲染输出必须与 monitor 开启时一致。
    func testMakeFrameHasNoObservableEffectWhenMonitorDisabled() throws {
        Shared.shared.enablePerformanceMonitor = false

        let input = try makeSolidTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.2))

        let frame = try node.makeFrame()

        // 监控关闭时 monitor 为 nil
        XCTAssertNil(Shared.shared.performanceMonitor)

        // 渲染输出必须正常（texture 有效、identifier 仍以 ImageNode. 开头）
        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(frame.texture.height, 4)
        XCTAssertTrue(frame.token.identifier.hasPrefix("ImageNode."),
                      "FrameRenderToken.identifier should still be ImageNode-prefixed, got \(frame.token.identifier)")
    }

    // MARK: - 测试 helper

    private func makeSolidTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal device is unavailable.")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor), "Failed to create texture.")
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = 4 * width
        var pixels = [UInt8]()
        for _ in 0..<(width * height) {
            pixels.append(contentsOf: pixel)
        }
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }
        return texture
    }
}
