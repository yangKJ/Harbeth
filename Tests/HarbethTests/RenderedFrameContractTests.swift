import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
import ImageIO
import CoreGraphics
import Metal
@testable import Harbeth

final class RenderedFrameContractTests: XCTestCase {
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
