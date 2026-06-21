import XCTest
import Metal
import CoreGraphics
import CoreVideo
@testable import Harbeth

final class TextureReadbackTests: XCTestCase {

    func testHalfFloatPixelBufferTextureLoaderPrefersRGBA16Float() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_64RGBAHalf,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        let contract = pixelBuffer.c7.contract
        XCTAssertEqual(contract.preferredMetalPixelFormat, .rgba16Float)

        let texture = try TextureLoader(with: pixelBuffer).texture
        #if targetEnvironment(simulator)
        XCTAssertTrue(texture.pixelFormat == .rgba8Unorm || texture.pixelFormat == .rgba16Float)
        #else
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        #endif
    }

    func testHalfFloatPixelBufferDirectMetalBridgeUsesRGBA16FloatWhenAvailable() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct CVMetalTexture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_64RGBAHalf,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        var cache: CVMetalTextureCache?
        XCTAssertEqual(CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &cache), kCVReturnSuccess)
        let texture = pixelBuffer.c7.convert2MTLTexture(textureCache: cache, pixelFormat: .rgba16Float)

        XCTAssertEqual(texture?.pixelFormat, .rgba16Float)
        #endif
    }

    func testBGRAContainingPixelBufferTextureProducesVisibleCGImage() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            XCTFail("Pixel buffer has no base address.")
            return
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rows = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<2 {
            for x in 0..<2 {
                let offset = y * bytesPerRow + x * 4
                rows[offset + 0] = 0
                rows[offset + 1] = 64
                rows[offset + 2] = 255
                rows[offset + 3] = 255
            }
        }

        var cache: CVMetalTextureCache?
        XCTAssertEqual(CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &cache), kCVReturnSuccess)
        guard let texture = pixelBuffer.c7.convert2MTLTexture(textureCache: cache, pixelFormat: .bgra8Unorm),
              let cgImage = texture.c7.toCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()) else {
            XCTFail("Expected BGRA pixel buffer texture to produce a CGImage.")
            return
        }

        XCTAssertFalse(cgImageIsFullyTransparent(cgImage))
    }

    func testManagedTextureWrittenByGPUProducesVisibleCGImageOnMacOS() throws {
        #if os(macOS)
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let queue = device!.makeCommandQueue()
        try XCTSkipIf(queue == nil, "Metal command queue is unavailable in this environment.")

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.storageMode = .managed
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device!.makeTexture(descriptor: descriptor),
              let commandBuffer = queue!.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            XCTFail("Failed to create managed texture writeback fixtures.")
            return
        }

        var pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 0, 255
        ]
        guard let source = device!.makeBuffer(bytes: &pixels, length: pixels.count, options: .storageModeShared) else {
            XCTFail("Failed to create source pixel buffer.")
            return
        }
        blit.copy(
            from: source,
            sourceOffset: 0,
            sourceBytesPerRow: 8,
            sourceBytesPerImage: pixels.count,
            sourceSize: MTLSize(width: 2, height: 2, depth: 1),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let cgImage = texture.c7.toCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()) else {
            XCTFail("Expected managed texture readback to create a CGImage.")
            return
        }

        XCTAssertFalse(cgImageIsFullyTransparent(cgImage))
        #else
        throw XCTSkip("Managed texture CPU readback is a macOS-specific regression test.")
        #endif
    }

    private func cgImageIsFullyTransparent(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        let rowBytes = width * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return true
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 0 }
    }
}
