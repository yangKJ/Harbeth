import XCTest
import CoreImage
import CoreVideo
import Metal
@testable import Harbeth

final class CIImageSourceTests: XCTestCase {
    func testHarbethIOProcessesCIImageAndReturnsCIImage() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let output: CIImage = try HarbethIO(
            element: source,
            filters: [C7Brightness(brightness: 0)]
        ).output()

        XCTAssertEqual(output.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
        XCTAssertNotNil(output.cgImage)
    }

    func testTypedTextureBackedFrameMaterializesEmptyFilterChainOnGPU() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let output = try makeTextureBackedFrame(source: source)

        XCTAssertEqual(output.image.extent, source.extent)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, *) {
            XCTAssertNotNil(output.image.metalTexture)
            XCTAssertNil(output.image.cgImage)
        }
    }

    func testTextureLoaderKeepsFiniteCIImageInputOnGPU() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let texture = try TextureLoader(with: source).texture

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 3)
    }

    func testTypedTextureBackedFrameRetainsOutputContracts() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)
            .transformed(by: CGAffineTransform(translationX: 7, y: 11))

        let output = try makeTextureBackedFrame(
            source: source,
            filters: [C7PremultiplyAlpha()],
            profile: .responseLatency,
            outputColorSpace: .displayP3
        )

        XCTAssertEqual(output.image.extent, source.extent)
        XCTAssertEqual(output.sourceDescriptor.kind, "ciImage")
        XCTAssertEqual(output.outputColorSpaceContract, .displayP3)
        XCTAssertEqual(output.outputDynamicRange, .standardDynamicRange)
        XCTAssertEqual(output.outputToneMappingPolicy, .preserveInput)
        XCTAssertEqual(output.profile, .responseLatency)
        XCTAssertNil(output.image.cgImage)
        XCTAssertEqual(output.texture.width, 4)
        XCTAssertEqual(output.texture.height, 3)
    }

    func testTypedTextureBackedFrameOwnsManagedTextureLease() throws {
        try requireMetal()
        HarbethContext.shared.recoverExecution()
        var output: TextureBackedCIImageFrame? = try makeTextureBackedFrame(
            source: makeCIImage(width: 9, height: 7),
            filters: [C7Brightness(brightness: 0.1)]
        )
        let texture = try XCTUnwrap(output?.texture)

        XCTAssertNil(
            HarbethContext.shared.texturePool.dequeueExactTexture(
                width: texture.width,
                height: texture.height,
                pixelFormat: texture.pixelFormat
            )
        )

        output = nil

        let reused = HarbethContext.shared.texturePool.dequeueExactTexture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        XCTAssertTrue(reused === texture)
    }

    func testTypedTextureBackedFramePreservesSourcePixelOrientation() throws {
        try requireMetal()
        let source = makeAsymmetricCIImage()
        let output = try makeTextureBackedFrame(source: source, filters: [C7Brightness(brightness: 0)])

        XCTAssertEqual(try renderedBytes(output.image), try renderedBytes(source))
    }

    func testTypedTextureBackedFramePreservesPixelBufferSourceOrientation() throws {
        try requireMetal()
        let source = CIImage(cvPixelBuffer: try makeAsymmetricPixelBuffer())
        let output = try makeTextureBackedFrame(source: source, filters: [C7Brightness(brightness: 0)])

        XCTAssertEqual(try renderedBytes(output.image), try renderedBytes(source))
    }

    func testTypedTextureBackedFramePreservesMetalTextureSourceOrientation() throws {
        try requireMetal()
        let source = try makeAsymmetricMetalImage()
        let output = try makeTextureBackedFrame(source: source, filters: [C7Brightness(brightness: 0)])

        XCTAssertEqual(try renderedBytes(output.image), try renderedBytes(source))
    }

    func testEscapedTextureBackedImageKeepsManagedLease() throws {
        try requireMetal()
        HarbethContext.shared.recoverExecution()
        var output: TextureBackedCIImageFrame? = try makeTextureBackedFrame(
            source: makeCIImage(width: 11, height: 7),
            filters: [C7Brightness(brightness: 0.1)]
        )
        let texture = try XCTUnwrap(output?.texture)
        var escapedImage: CIImage? = output?.image

        output = nil

        XCTAssertNotNil(escapedImage)
        XCTAssertNil(
            HarbethContext.shared.texturePool.dequeueExactTexture(
                width: texture.width,
                height: texture.height,
                pixelFormat: texture.pixelFormat
            )
        )

        escapedImage = nil

        let reused = HarbethContext.shared.texturePool.dequeueExactTexture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        XCTAssertTrue(reused === texture)
    }

    func testCroppedTextureBackedImageKeepsManagedLease() throws {
        try requireMetal()
        HarbethContext.shared.recoverExecution()
        let texture = try autoreleasepool { () throws -> MTLTexture in
            var output: TextureBackedCIImageFrame? = try makeTextureBackedFrame(
                source: makeCIImage(width: 13, height: 9),
                filters: [C7Brightness(brightness: 0.1)]
            )
            let texture = try XCTUnwrap(output?.texture)
            var escapedImage = output?.croppedImage(to: CGRect(x: 1, y: 1, width: 10, height: 6))

            output = nil

            XCTAssertNotNil(escapedImage)
            XCTAssertNil(
                HarbethContext.shared.texturePool.dequeueExactTexture(
                    width: texture.width,
                    height: texture.height,
                    pixelFormat: texture.pixelFormat
                )
            )

            escapedImage = nil
            return texture
        }

        let reused = HarbethContext.shared.texturePool.dequeueExactTexture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        XCTAssertTrue(reused === texture)
    }

    func testHarbethIOTransmitsCIImageAsynchronously() throws {
        try requireMetal()
        let expectation = expectation(description: "CIImage asynchronous output")
        let source = makeCIImage(width: 4, height: 3)

        HarbethIO(element: source, filters: [C7Brightness(brightness: 0)])
            .transmitOutput { (result: Result<CIImage, HarbethError>) in
                switch result {
                case .success(let output):
                    XCTAssertEqual(output.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
                case .failure(let error):
                    XCTFail("Unexpected CIImage output failure: \(error)")
                }
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 2)
    }

    func testHarbethIOCIImageOutputRemainsDirect() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let single: CIImage = try HarbethIO(element: source, filter: C7Brightness(brightness: 0)).output()
        let grouped: CIImage = try HarbethIO(element: source, filters: [C7Brightness(brightness: 0)]).output()

        XCTAssertEqual(single.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
        XCTAssertEqual(grouped.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
    }

    func testHarbethIORenderFrameAcceptsCIImage() throws {
        try requireMetal()

        let frame = try ImageNode
            .ciImage(makeCIImage(width: 5, height: 2))
            .makeFrame(profile: .stablePreview)

        XCTAssertEqual(frame.sourceDescriptor.kind, "ciImage")
        XCTAssertEqual(frame.texture.width, 5)
        XCTAssertEqual(frame.texture.height, 2)
    }

    func testImageNodeAcceptsCIImage() throws {
        try requireMetal()

        let texture = try ImageNode
            .ciImage(makeCIImage(width: 6, height: 4))
            .applying(C7Brightness(brightness: 0))
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(texture.width, 6)
        XCTAssertEqual(texture.height, 4)
    }

    private func makeTextureBackedFrame(
        source: CIImage,
        filters: [C7FilterProtocol] = [],
        profile: RenderProfile = .stablePreview,
        outputColorSpace: ImageColorSpaceContract? = nil
    ) throws -> TextureBackedCIImageFrame {
        try ImageNode
            .ciImage(source)
            .applying(filters: filters)
            .makeFrame(profile: profile, outputColorSpace: outputColorSpace)
            .makeTextureBackedCIImage(for: source)
    }

    func testPluginOutputTreatsCIImageAsSource() throws {
        try requireMetal()
        let output = PluginOutput.ciImage(makeCIImage(width: 3, height: 2))

        XCTAssertTrue(output.isSourceLike)
        XCTAssertEqual(output.kind, "ciImage")
        XCTAssertEqual(try output.sourceDescriptor().kind, "ciImage")

        let texture = try ImageNode
            .texture(try TextureLoader.makeTexture(width: 1, height: 1))
            .applying(pluginOutput: output)
            .makeTexture(profile: .stablePreview)
        XCTAssertEqual(texture.width, 3)
        XCTAssertEqual(texture.height, 2)
    }

    func testInfiniteExtentCIImageFailsExplicitly() throws {
        try requireMetal()
        let source = CIImage(color: CIColor(red: 1, green: 0, blue: 0))

        XCTAssertThrowsError(try ImageSource.ciImage(source).makeTexture()) { error in
            guard case HarbethError.configurationInvalid(let message) = error else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("finite"))
        }
    }

    private func makeCIImage(width: Int, height: Int) -> CIImage {
        CIImage(color: CIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func makeAsymmetricCIImage() -> CIImage {
        let bytes: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 255, 255
        ]
        return CIImage(
            bitmapData: Data(bytes),
            bytesPerRow: 8,
            size: CGSize(width: 2, height: 2),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
    }

    private func makeAsymmetricPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw HarbethError.texture2Image
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw HarbethError.texture2Image
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rows: [[UInt8]] = [
            [0, 0, 255, 255, 0, 255, 0, 255],
            [255, 0, 0, 255, 255, 255, 255, 255]
        ]
        for (rowIndex, row) in rows.enumerated() {
            row.withUnsafeBytes { bytes in
                baseAddress.advanced(by: rowIndex * bytesPerRow)
                    .copyMemory(from: bytes.baseAddress!, byteCount: row.count)
            }
        }
        return pixelBuffer
    }

    private func makeAsymmetricMetalImage() throws -> CIImage {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let bytes: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 255, 255
        ]
        bytes.withUnsafeBytes { buffer in
            texture.replace(
                region: MTLRegionMake2D(0, 0, 2, 2),
                mipmapLevel: 0,
                withBytes: buffer.baseAddress!,
                bytesPerRow: 8
            )
        }
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        return try XCTUnwrap(CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace]))
    }

    private func renderedBytes(_ image: CIImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 16)
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        CIContext(options: [.cacheIntermediates: false]).render(
            image,
            toBitmap: &bytes,
            rowBytes: 8,
            bounds: image.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
        return bytes
    }

    private func requireMetal() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
    }
}
