//
//  YCbCrSubmissionTests.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import CoreVideo
import Metal
@testable import Harbeth

final class YCbCrSubmissionTests: XCTestCase {
    func testNV12PlaneAwareIOMatchesSynchronousDecodeAndUsesOneCommandBuffer() throws {
        let buffer = try makeNV12()
        let filter = C7Brightness(brightness: 0.05)
        let legacy = try TextureLoader(with: buffer).texture
        let expected: MTLTexture = try HarbethIO(element: legacy, filter: filter).output()
        let monitor = HarbethContext.shared.performanceMonitor
        let previousMonitoring = HarbethContext.shared.enablePerformanceMonitor
        HarbethContext.shared.enablePerformanceMonitor = true
        monitor.clearAllMetrics()
        defer { HarbethContext.shared.enablePerformanceMonitor = previousMonitoring }
        let source = ImageSource.pixelBuffer(buffer)
        let io = try XCTUnwrap(source.planeAwareIO(filters: [filter], profile: .stablePreview, identifier: "YCbCrSubmissionTests.NV12"))
        let before = monitor.gpuWorkSnapshot().commandBufferCount
        let actual: MTLTexture = try io.output()
        XCTAssertEqual(try XCTUnwrap(actual.c7.rawBytes(maximumBytes: 1024)), try XCTUnwrap(expected.c7.rawBytes(maximumBytes: 1024)))
        XCTAssertEqual(monitor.gpuWorkSnapshot().commandBufferCount - before, 1)
    }

    func testP010PlaneAwareIOMatchesSynchronousDecode() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("模拟器不支持直接 P010 纹理桥接")
        #else
        let buffer = try makeP010()
        let filter = C7Brightness(brightness: 0.02)
        let legacy = try TextureLoader(with: buffer).texture
        let expected: MTLTexture = try HarbethIO(element: legacy, filter: filter).output()
        let io = try XCTUnwrap(ImageSource.pixelBuffer(buffer).planeAwareIO(filters: [filter], profile: .stablePreview, identifier: "YCbCrSubmissionTests.P010"))
        let actual: MTLTexture = try io.output()
        XCTAssertEqual(try XCTUnwrap(actual.c7.rawBytes(maximumBytes: 1024)), try XCTUnwrap(expected.c7.rawBytes(maximumBytes: 1024)))
        #endif
    }

    func testImageNodePixelBufferSourceUsesPlaneAwarePath() throws {
        let buffer = try makeNV12()
        let node = ImageNode.pixelBuffer(buffer).applying(C7Brightness(brightness: 0.03))
        let frame = try node.makeFrame()
        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(frame.texture.height, 4)
        XCTAssertEqual(frame.sourceDescriptor.pixelBufferContract?.planeCount, 2)
    }

    func testAsyncFrameKeepsSourceContractAndMatchesCompletedPixels() async throws {
        let buffer = try makeNV12()
        let filter = C7Brightness(brightness: 0.03)
        let node = ImageNode.pixelBuffer(buffer).applying(filter)
        let frame = try await node.makeFrameAsync()
        let original = try TextureLoader(with: buffer).texture
        let expected: MTLTexture = try HarbethIO(element: original, filter: filter).output()
        XCTAssertEqual(try XCTUnwrap(frame.texture.c7.rawBytes(maximumBytes: 1024)),
                       try XCTUnwrap(expected.c7.rawBytes(maximumBytes: 1024)))
        XCTAssertEqual(frame.sourceDescriptor.pixelBufferContract?.planeCount, 2)
    }

    private func makeNV12() throws -> CVPixelBuffer {
        try makePlanar(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, yValue: 128, uvValue: 128)
    }

    private func makeP010() throws -> CVPixelBuffer {
        try makePlanar(format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, yValue: 512 << 6, uvValue: 512 << 6)
    }

    private func makePlanar(format: OSType, yValue: Int, uvValue: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferPixelFormatTypeKey: format, kCVPixelBufferWidthKey: 4, kCVPixelBufferHeightKey: 4, kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, format, attrs as CFDictionary, &buffer)
        try XCTSkipIf(status != kCVReturnSuccess || buffer == nil, "YCbCr pixel buffer unavailable: \(status)")
        let value = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(value, [])
        defer { CVPixelBufferUnlockBaseAddress(value, []) }
        let tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(value, 0), uvStride = CVPixelBufferGetBytesPerRowOfPlane(value, 1)
        let yBase = CVPixelBufferGetBaseAddressOfPlane(value, 0)!, uvBase = CVPixelBufferGetBaseAddressOfPlane(value, 1)!
        for row in 0..<4 { for column in 0..<4 { if tenBit { yBase.storeBytes(of: UInt16(yValue), toByteOffset: row * yStride + column * 2, as: UInt16.self) } else { yBase.storeBytes(of: UInt8(yValue), toByteOffset: row * yStride + column, as: UInt8.self) } } }
        for row in 0..<2 { for column in 0..<2 { if tenBit { uvBase.storeBytes(of: UInt16(uvValue), toByteOffset: row * uvStride + column * 4, as: UInt16.self); uvBase.storeBytes(of: UInt16(uvValue), toByteOffset: row * uvStride + column * 4 + 2, as: UInt16.self) } else { uvBase.storeBytes(of: UInt8(uvValue), toByteOffset: row * uvStride + column * 2, as: UInt8.self); uvBase.storeBytes(of: UInt8(uvValue), toByteOffset: row * uvStride + column * 2 + 1, as: UInt8.self) } } }
        return value
    }
}
