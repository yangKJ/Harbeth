//
//  YCbCrSubmissionTests.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import CoreVideo
import CoreImage
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

    func testExternalPlaneDecodeGeometryMatchesSeparateClampedInterpolation() async throws {
        let formats: [OSType] = [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange]
        let transforms: [CGAffineTransform] = [.identity, .init(a: 0, b: 1, c: -1, d: 0, tx: 1, ty: 0),
            .init(translationX: -0.2, y: 0.1)]
        let context = CIContext()
        for format in formats {
            let buffer = try makePlanar(format: format, yValue: 128, uvValue: 128, width: 32, height: 24, patterned: true)
            for matrix in [kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVImageBufferYCbCrMatrix_ITU_R_709_2] {
                CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, matrix, .shouldPropagate)
                for transform in transforms {
                    let geometry = try C7TextureGeometry(width: 13, height: 9,
                        sourceRect: CGRect(x: 0.1, y: 0.15, width: 0.7, height: 0.75),
                        destinationRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                        mirrorsHorizontally: true, flipsVertically: true,
                        background: SIMD4(0.1, 0.2, 0.3, 1), sampleTransform: transform)
                    for working in [ImageColorSpaceContract.sRGB, .displayP3] {
                        let referenceCommand = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
                        let decoded = try ImageNode.pixelBuffer(buffer).encodeFrame(into: referenceCommand,
                            inputColorSpace: .sRGB, workingColorSpace: .sRGB)
                        let expected = try ImageNode.texture(decoded.texture).applying(geometry).encodeFrame(into: referenceCommand,
                            inputColorSpace: .sRGB, workingColorSpace: working)
                        referenceCommand.addCompletedHandler { _ in withExtendedLifetime(decoded) {} }
                        await withCheckedContinuation { continuation in
                            referenceCommand.addCompletedHandler { _ in continuation.resume() }
                            referenceCommand.commit()
                        }
                        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
                        let actual = try ImageNode.pixelBuffer(buffer).applying(geometry).encodeFrame(into: command,
                            inputColorSpace: .sRGB, workingColorSpace: working)
                        await withCheckedContinuation { continuation in
                            command.addCompletedHandler { _ in continuation.resume() }
                            command.commit()
                        }
                        XCTAssertEqual(actual.texture.width, 13)
                        XCTAssertEqual(actual.texture.height, 9)
                        let color = CGColorSpace(name: working == .sRGB ? CGColorSpace.sRGB : CGColorSpace.displayP3)!
                        func samples(_ frame: RenderedFrame) throws -> [Float] {
                            var result = [Float](repeating: 0, count: 13 * 9 * 4)
                            context.render(try frame.makeTextureBackedCIImage().image, toBitmap: &result, rowBytes: 13 * 16,
                                bounds: CGRect(x: 0, y: 0, width: 13, height: 9), format: .RGBAf, colorSpace: color)
                            return result
                        }
                        let a = try samples(actual)
                        let b = try samples(expected)
                        XCTAssertTrue(a.allSatisfy(\.isFinite))
                        XCTAssertLessThanOrEqual(zip(a, b).map { abs($0 - $1) }.max() ?? 0, 1.0 / 255)
                    }
                }
            }
        }
    }

    func testFusedDecodedFrameKeepsItsPoolLeaseWhileTheResultIsRetained() async throws {
        let geometry = try C7TextureGeometry(width: 2, height: 2)
        func render(_ buffer: CVPixelBuffer) async throws -> RenderedFrame {
            let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
            let frame = try ImageNode.pixelBuffer(buffer).applying(geometry).encodeFrame(into: command,
                inputColorSpace: .sRGB, workingColorSpace: .sRGB)
            await withCheckedContinuation { continuation in
                command.addCompletedHandler { _ in continuation.resume() }
                command.commit()
            }
            return frame
        }
        let white = try makePlanar(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, yValue: 230, uvValue: 128)
        let first = try await render(white)
        let expected = try XCTUnwrap(first.texture.c7.rawBytes(maximumBytes: 1024))
        for _ in 0..<4 {
            let dark = try makePlanar(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, yValue: 20, uvValue: 128)
            _ = try await render(dark)
        }
        XCTAssertEqual(try XCTUnwrap(first.texture.c7.rawBytes(maximumBytes: 1024)), expected)
    }

    func testTriPlanarGeometryKernelMatchesSeparateDecodeAtChromaBoundaries() async throws {
        let buffer = try makeNV12()
        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: buffer, bridgePlan: buffer.c7.makeTextureBridgePlan()))
        func plane(width: Int, height: Int, salt: Int) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = [.shaderRead]
            let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
            let values = (0..<(width * height)).map { UInt8(($0 * 37 + salt) % 256) }
            values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                withBytes: $0.baseAddress!, bytesPerRow: width) }
            return texture
        }
        let y = try plane(width: 32, height: 24, salt: 10)
        let u = try plane(width: 16, height: 12, salt: 80)
        let v = try plane(width: 16, height: 12, salt: 150)
        let geometry = try C7TextureGeometry(width: 13, height: 9,
            sourceRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), mirrorsHorizontally: true)
        let normal = YCbCrPlaneDecodeFilter(layout: .triPlanar, conversionMatrix: strategy.conversionMatrix,
            conversionOffset: strategy.conversionOffset, planeTextures: [y, u, v])
        var fused = normal
        fused.geometry = geometry
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let decoded = try ImageNode.texture(y).applying(normal).encodeFrame(into: command, inputColorSpace: .sRGB, workingColorSpace: .sRGB)
        let expected = try ImageNode.texture(decoded.texture).applying(geometry).encodeFrame(into: command,
            inputColorSpace: .sRGB, workingColorSpace: .sRGB)
        let actual = try ImageNode.texture(y).applying(fused).encodeFrame(into: command, inputColorSpace: .sRGB, workingColorSpace: .sRGB)
        command.addCompletedHandler { _ in withExtendedLifetime(decoded) {} }
        await withCheckedContinuation { continuation in
            command.addCompletedHandler { _ in continuation.resume() }
            command.commit()
        }
        let context = CIContext()
        func samples(_ frame: RenderedFrame) throws -> [Float] {
            var result = [Float](repeating: 0, count: 13 * 9 * 4)
            context.render(try frame.makeTextureBackedCIImage().image, toBitmap: &result, rowBytes: 13 * 16,
                bounds: CGRect(x: 0, y: 0, width: 13, height: 9), format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            return result
        }
        let a = try samples(actual)
        let b = try samples(expected)
        XCTAssertLessThanOrEqual(zip(a, b).map { abs($0 - $1) }.max() ?? 0, 1.0 / 255)
    }

    private func makeNV12() throws -> CVPixelBuffer {
        try makePlanar(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, yValue: 128, uvValue: 128)
    }

    private func makeP010() throws -> CVPixelBuffer {
        try makePlanar(format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, yValue: 512 << 6, uvValue: 512 << 6)
    }

    private func makePlanar(format: OSType, yValue: Int, uvValue: Int, width: Int = 4, height: Int = 4, patterned: Bool = false) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferPixelFormatTypeKey: format, kCVPixelBufferWidthKey: width, kCVPixelBufferHeightKey: height, kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, attrs as CFDictionary, &buffer)
        try XCTSkipIf(status != kCVReturnSuccess || buffer == nil, "YCbCr pixel buffer unavailable: \(status)")
        let value = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(value, [])
        defer { CVPixelBufferUnlockBaseAddress(value, []) }
        let tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(value, 0), uvStride = CVPixelBufferGetBytesPerRowOfPlane(value, 1)
        let yBase = CVPixelBufferGetBaseAddressOfPlane(value, 0)!, uvBase = CVPixelBufferGetBaseAddressOfPlane(value, 1)!
        for row in 0..<height {
            for column in 0..<width {
                if tenBit {
                    let sample = patterned ? ((row * 37 + column * 71) % 1024) << 6 : yValue
                    yBase.storeBytes(of: UInt16(sample), toByteOffset: row * yStride + column * 2, as: UInt16.self)
                } else {
                    let sample = patterned ? (row * 17 + column * 23) % 256 : yValue
                    yBase.storeBytes(of: UInt8(sample), toByteOffset: row * yStride + column, as: UInt8.self)
                }
            }
        }
        for row in 0..<(height / 2) {
            for column in 0..<(width / 2) {
                if tenBit {
                    let u = patterned ? ((row * 53 + column * 19) % 1024) << 6 : uvValue
                    let v = patterned ? ((row * 29 + column * 67) % 1024) << 6 : uvValue
                    uvBase.storeBytes(of: UInt16(u), toByteOffset: row * uvStride + column * 4, as: UInt16.self)
                    uvBase.storeBytes(of: UInt16(v), toByteOffset: row * uvStride + column * 4 + 2, as: UInt16.self)
                } else {
                    let u = patterned ? (row * 53 + column * 19) % 256 : uvValue
                    let v = patterned ? (row * 29 + column * 67) % 256 : uvValue
                    uvBase.storeBytes(of: UInt8(u), toByteOffset: row * uvStride + column * 2, as: UInt8.self)
                    uvBase.storeBytes(of: UInt8(v), toByteOffset: row * uvStride + column * 2 + 1, as: UInt8.self)
                }
            }
        }
        return value
    }
}
