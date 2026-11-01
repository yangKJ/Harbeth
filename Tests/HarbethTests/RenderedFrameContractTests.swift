import XCTest
import CoreImage
import AVFoundation
import CoreMedia
import CoreVideo
import ImageIO
import CoreGraphics
import Metal
@testable import Harbeth

final class RenderedFrameContractTests: XCTestCase {
    func testExplicitTextureOutputContractsRetainFrameIdentity() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try RGBA8ImageBuffer(width: 2, height: 1, bytes: [255, 0, 0, 255, 0, 128, 0, 128], colorSpace: space).makeCGImage()
        let source = try ImageNode.cgImage(image).makeFrame(profile: .exportQuality)
        let converted = try source.converted(to: RenderOutputContract.displayP3Texture)
        XCTAssertEqual(converted.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(converted.colorSpace?.name, CGColorSpace.displayP3)
        XCTAssertEqual(converted.token, source.token)
        XCTAssertEqual(converted.alphaType, source.alphaType)
        XCTAssertEqual(converted.texture.width, 2)
        XCTAssertFalse(converted.texture === source.texture)
        XCTAssertTrue(try source.converted(to: RenderOutputContract.preserveInput).texture === source.texture)
    }

    func testICCConversionUsesIndependentTextureAndPreservesAlpha() throws {
        let srgb = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let p3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let image = try RGBA8ImageBuffer(width: 1, height: 1, bytes: [255, 0, 0, 255], colorSpace: srgb).makeCGImage()
        let source = try ImageNode.cgImage(image).makeFrame(profile: .exportQuality)
        let result = try source.converted(to: p3)
        XCTAssertFalse(result.texture === source.texture)
        XCTAssertEqual(result.pixelFormat, .rgba16Float)
        XCTAssertEqual(result.colorSpace?.name, p3.name)
        let ci = try result.makeTextureBackedCIImage().image
        var values = [Float](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(ci, toBitmap: &values, rowBytes: 16,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: p3)
        XCTAssertEqual(values[0], 0.9175, accuracy: 0.005)
        XCTAssertEqual(values[1], 0.2003, accuracy: 0.005)
        XCTAssertEqual(values[2], 0.1386, accuracy: 0.005)
        XCTAssertEqual(values[3], 1, accuracy: 0.001)
        XCTAssertEqual(source.colorSpace?.name, srgb.name)
    }

    func testICCConversionRoundTripRetainsStraightAlpha() throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        let input: [Float16] = [0.4, 0.2, 0.1, 0.5]
        input.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        let srgb = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let p3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let source = RenderedFrame(texture: texture, colorSpace: srgb, alphaType: .nonPremultiplied,
            profile: .exportQuality, generation: 1, identifier: "straight-icc")
        let result = try source.converted(to: p3).converted(to: srgb)
        XCTAssertEqual(result.alphaType, .nonPremultiplied)
        let image = try XCTUnwrap(CIImage(mtlTexture: result.texture, options: [.colorSpace: NSNull()]))
        var actual = [Float](repeating: 0, count: 4)
        HarbethContext.shared.numericImageContext.render(image, toBitmap: &actual, rowBytes: 16,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        for (value, expected) in zip(actual, input) { XCTAssertEqual(value, Float(expected), accuracy: 0.005) }
    }

    private func assertSizeContract(_ frame: RenderedFrame, sourceWidth: Int, sourceHeight: Int) {
        XCTAssertEqual(Int(frame.sourcePixelSize.width), sourceWidth)
        XCTAssertEqual(Int(frame.sourcePixelSize.height), sourceHeight)
        XCTAssertEqual(Int(frame.textureSize.width), sourceWidth)
        XCTAssertEqual(Int(frame.textureSize.height), sourceHeight)
        XCTAssertEqual(Int(frame.displaySize.width), sourceWidth)
        XCTAssertEqual(Int(frame.displaySize.height), sourceHeight)
        XCTAssertEqual(Int(frame.outputImageSize.width), sourceWidth)
        XCTAssertEqual(Int(frame.outputImageSize.height), sourceHeight)
    }

    @MainActor func testSampleBufferToFrameContractAndImageSize() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let pixelBuffer = try makePixelBuffer(
            width: 4224,
            height: 2376,
            pixelFormatType: kCVPixelFormatType_32BGRA
        )
        let sampleBuffer = try makeSampleBuffer(from: pixelBuffer, orientation: .right)

        let frame = try ImageNode
            .sampleBuffer(sampleBuffer)
            .applying(C7Sharpen(sharpness: 0.2))
            .makeFrame(profile: .interactiveLatency)

        assertSizeContract(frame, sourceWidth: CVPixelBufferGetWidth(pixelBuffer), sourceHeight: CVPixelBufferGetHeight(pixelBuffer))
        XCTAssertTrue(
            frame.previewHostStrategyResolution.strategy == .sampleBufferRematerializedHost ||
            frame.previewHostStrategyResolution.strategy == .metalTextureHost
        )

        let outputImage = try XCTUnwrap(try frame.makeImage())
        XCTAssertEqual(outputImage.size.width, 4224)
        XCTAssertEqual(outputImage.size.height, 2376)

        let renderView = RenderView(frame: .zero)
        renderView.display(frame)
        XCTAssertTrue(
            renderView.currentPreviewHostStrategy == PreviewHostStrategy.sampleBufferRematerializedHost.rawValue ||
            renderView.currentPreviewHostStrategy == PreviewHostStrategy.metalTextureHost.rawValue
        )
    }

    func testPixelBufferToFrameContractAndImageSize() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 3,
            pixelFormatType: kCVPixelFormatType_32BGRA
        )
        let frame = try ImageNode.pixelBuffer(pixelBuffer)
            .makeFrame(profile: .interactiveLatency, metadata: ["previewRoute": "ImageNode+RenderView(pixelBuffer)"])

        assertSizeContract(frame, sourceWidth: 4, sourceHeight: 3)
        XCTAssertEqual(frame.previewHostStrategyResolution.strategy, .metalTextureHost)

        let outputImage = try XCTUnwrap(try frame.makeImage())
        XCTAssertEqual(outputImage.size.width, 4)
        XCTAssertEqual(outputImage.size.height, 3)
    }

    func testTextureToFrameContractAndImageSize() throws {
        let texture = try TextureLoader.makeTexture(width: 3, height: 2, identifier: "RenderedFrameContractTests.texture")
        let frame = try ImageNode.texture(texture)
            .makeFrame(profile: .interactiveLatency, metadata: ["previewRoute": "ImageNode+RenderView(texture)"])

        assertSizeContract(frame, sourceWidth: 3, sourceHeight: 2)
        XCTAssertEqual(frame.previewHostStrategyResolution.strategy, .metalTextureHost)

        let outputImage = try XCTUnwrap(try frame.makeImage())
        XCTAssertEqual(outputImage.size.width, 3)
        XCTAssertEqual(outputImage.size.height, 2)
    }

    func testSampleBufferBiPlanarToFrameContractAndImageOrientation() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let pixelBuffer = try makePixelBuffer(
            width: 64,
            height: 64,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        )
        let sampleBuffer = try makeSampleBuffer(from: pixelBuffer, orientation: .left)
        let frame = try ImageNode
            .sampleBuffer(sampleBuffer)
            .applying(C7ColorMatrix4x4(matrix: Matrix4x4.Color.blackAndWhite))
            .makeFrame(profile: .interactiveLatency)

        assertSizeContract(frame, sourceWidth: 64, sourceHeight: 64)
        XCTAssertTrue(
            frame.previewHostStrategyResolution.strategy == .sampleBufferRematerializedHost ||
            frame.previewHostStrategyResolution.strategy == .metalTextureHost
        )

        if frame.previewHostStrategyResolution.strategy == .sampleBufferRematerializedHost {
            let hostSampleBuffer = try XCTUnwrap(try frame.makePreviewHostSampleBuffer())
            XCTAssertEqual(hostSampleBuffer.c7.contract.frameContract.orientation, .left)
        } else {
            XCTAssertNil(try frame.makePreviewHostSampleBuffer())
        }

        let outputImage = try XCTUnwrap(try frame.makeImage())
        XCTAssertEqual(outputImage.size.width, 64)
        XCTAssertEqual(outputImage.size.height, 64)
    }

    func testPixelBufferToFrameHostBypassContract() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let pixelBuffer = try makePixelBuffer(width: 12, height: 10, pixelFormatType: kCVPixelFormatType_32BGRA)
        let frame = try ImageNode
            .pixelBuffer(pixelBuffer)
            .makeFrame(profile: .interactiveLatency)

        XCTAssertEqual(frame.previewHostStrategyResolution.strategy, .metalTextureHost)
        XCTAssertNil(try frame.makePreviewHostSampleBuffer())
    }

    @MainActor func testSampleBufferDisplayRouteContract() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let pixelBuffer = try makePixelBuffer(width: 64, height: 128, pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        let sampleBuffer = try makeSampleBuffer(from: pixelBuffer, orientation: .up)
        let frame = try ImageNode
            .sampleBuffer(sampleBuffer)
            .makeFrame(profile: .interactiveLatency)

        let renderView = RenderView(frame: .zero)
        renderView.display(frame)
        XCTAssertEqual(renderView.currentFrameHostSourceDescriptor?.frameSize.width, 64)
        XCTAssertEqual(renderView.currentFrameHostSourceDescriptor?.frameSize.height, 128)
        XCTAssertEqual(renderView.currentPreviewHostEnqueueCount, 0)
    }

    func testRealtimePixelBufferPoolFallbackStats() throws {
        let descriptor = RenderPixelBufferDescriptor(width: 8, height: 8, pixelFormatType: kCVPixelFormatType_32BGRA, minimumBufferCount: 1)
        PixelBufferPool.purgeRealtimePool()
        PixelBufferPool.resetRealtimePoolMetrics()

        let first = try PixelBufferPool.acquire(for: descriptor, realtime: true)
        let second = try PixelBufferPool.acquire(for: descriptor, realtime: true)

        XCTAssertNotNil(first.buffer)
        XCTAssertNotNil(second.buffer)
        XCTAssertNotNil(first.buffer)
        XCTAssertEqual(PixelBufferPool.realtimePoolHitCount, 1)
        XCTAssertEqual(PixelBufferPool.realtimePoolMissCount, 1)
        XCTAssertEqual(PixelBufferPool.realtimeAllocationFallbackCount, 0)
    }

    func testRealtimeRegistryMetricsResetDoesNotPurgeAndPurgeForcesMiss() throws {
        PixelBufferPool.purgeRealtimePool()
        PixelBufferPool.resetRealtimePoolMetrics()
        let descriptor = RenderPixelBufferDescriptor(width: 8, height: 8, minimumBufferCount: 1)

        _ = try PixelBufferPool.acquire(for: descriptor, realtime: true)
        _ = try PixelBufferPool.acquire(for: descriptor, realtime: true)
        XCTAssertEqual(PixelBufferPool.realtimePoolMissCount, 1)
        XCTAssertEqual(PixelBufferPool.realtimePoolHitCount, 1)

        PixelBufferPool.resetRealtimePoolMetrics()
        _ = try PixelBufferPool.acquire(for: descriptor, realtime: true)
        XCTAssertEqual(PixelBufferPool.realtimePoolMissCount, 0)
        XCTAssertEqual(PixelBufferPool.realtimePoolHitCount, 1)

        PixelBufferPool.purgeRealtimePool()
        _ = try PixelBufferPool.acquire(for: descriptor, realtime: true)
        XCTAssertEqual(PixelBufferPool.realtimePoolMissCount, 1)
    }

    func testRealtimeRegistryEvictsLeastRecentlyUsedEntry() throws {
        PixelBufferPool.purgeRealtimePool()
        PixelBufferPool.resetRealtimePoolMetrics()
        let descriptors = (0..<5).map { RenderPixelBufferDescriptor(width: 8 + $0, height: 8) }
        for descriptor in descriptors {
            _ = try PixelBufferPool.acquire(for: descriptor, realtime: true)
        }
        XCTAssertEqual(PixelBufferPool.realtimePoolMissCount, 5)
        XCTAssertEqual(PixelBufferPool.realtimePoolHitCount, 0)

        _ = try PixelBufferPool.acquire(for: descriptors[0], realtime: true)
        XCTAssertEqual(PixelBufferPool.realtimePoolMissCount, 6)
        XCTAssertEqual(PixelBufferPool.realtimePoolHitCount, 0)
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> CMSampleBuffer {
        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        if formatStatus != noErr {
            throw HarbethError.pixelBufferCreationFailed
        }
        guard let formatDescription else {
            throw HarbethError.pixelBufferCreationFailed
        }
        var timing = CMSampleTimingInfo(duration: CMTime.invalid,
                                       presentationTimeStamp: CMTime(value: 0, timescale: 60),
                                       decodeTimeStamp: CMTime.invalid)
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        if sampleStatus != noErr || sampleBuffer == nil {
            throw HarbethError.pixelBufferCreationFailed
        }
        CMSetAttachment(
            sampleBuffer!,
            key: kCGImagePropertyOrientation,
            value: NSNumber(value: orientation.rawValue),
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        CMSetAttachment(
            sampleBuffer!,
            key: harbethFrameMirrorHorizontallyAttachmentKey,
            value: kCFBooleanFalse,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        return sampleBuffer!
    }

    private func makePixelBuffer(width: Int, height: Int, pixelFormatType: OSType) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        var status = kCVReturnSuccess
        if pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
            status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                pixelFormatType,
                [
                    kCVPixelBufferWidthKey: width,
                    kCVPixelBufferHeightKey: height,
                    kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
                    kCVPixelBufferIOSurfacePropertiesKey: [:],
                    kCVPixelBufferMetalCompatibilityKey: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: true
                ] as CFDictionary,
                &pixelBuffer
            )
        } else {
            status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                pixelFormatType,
                [
                    kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
                    kCVPixelBufferWidthKey: width,
                    kCVPixelBufferHeightKey: height,
                    kCVPixelBufferMetalCompatibilityKey: true,
                    kCVPixelBufferIOSurfacePropertiesKey: [:]
                ] as CFDictionary,
                &pixelBuffer
            )
        }
        if status != kCVReturnSuccess {
            throw HarbethError.pixelBufferCreationFailed
        }
        guard let pixelBuffer else {
            throw HarbethError.pixelBufferCreationFailed
        }
        return pixelBuffer
    }
}
