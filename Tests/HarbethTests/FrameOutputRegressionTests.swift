// 由 Condy 创建于 2026/11/18。验证可变帧、派生所有权与实际色彩转换。
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Metal
import XCTest
@testable import Harbeth

final class FrameOutputRegressionTests: XCTestCase {
    func testConvertedFrameReadsNewPixelsFromReusedTexture() throws {
        let texture = try NeighborhoodTestImage.make(width: 1, height: 1, values: [1, 0, 0, 1])
        let first = try sourceFrame(texture, generation: 1).converted(to: .displayP3Texture)
        let blue: [Float16] = [0, 0, 1, 1]
        blue.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8)
        }
        let second = try sourceFrame(texture, generation: 2).converted(to: .displayP3Texture)
        let control = try sourceFrame(NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 1, 1]), generation: 2)
            .converted(to: .displayP3Texture)
        XCTAssertNotEqual(first.texture.c7.bytes(), second.texture.c7.bytes())
        XCTAssertEqual(second.texture.c7.bytes(), control.texture.c7.bytes())
    }

    func testRedundantContractRetainsLeaseAndDeliveryMetadata() throws {
        let texture = try NeighborhoodTestImage.make(width: 2, height: 1, values: [0.2, 0.1, 0, 0.5, 0.1, 0.2, 0, 0.5])
        weak var originalLease: TextureLease?
        let output = try autoreleasepool {
            let rendered = try ImageNode.texture(texture).applying(C7Brightness(brightness: 0.1)).makeFrame()
            originalLease = rendered.lease
            let source = RenderedFrame(texture: rendered.texture, colorSpace: CGColorSpace(name: CGColorSpace.sRGB),
                derivative: .init(name: "retained", renderIntent: .export, sourceTier: .original,
                    semantic: .sourceOriginal, outputSizePolicy: .source),
                sourceTier: .original, alphaType: .premultiplied, orientation: .right, profile: .exportQuality,
                token: rendered.token, metadata: ["owner": "retained"], lease: rendered.lease)
            let output = try source.converted(to: RenderOutputContract(alpha: .premultiplied))
            XCTAssertTrue(output.texture === rendered.texture)
            XCTAssertEqual(output.derivative, source.derivative)
            XCTAssertEqual(output.renderIntent, source.renderIntent)
            return output
        }
        XCTAssertNotNil(originalLease)
        XCTAssertTrue(output.lease === originalLease)
        XCTAssertEqual(output.orientation, .right)
        XCTAssertEqual(output.metadata, ["owner": "retained"])
        XCTAssertNotNil(output.sourceOwner)
        XCTAssertFalse(try NeighborhoodTestImage.read(output.texture).isEmpty)
    }

    func testFrameAndTextureRoutesAgreeOnAlphaAndSampler() throws {
        let texture = try NeighborhoodTestImage.make(width: 3, height: 1,
            values: [0.2, 0.1, 0.05, 0.5, 0.1, 0.15, 0.2, 0.5, 0, 0, 0, 0])
        let node = ImageNode.texture(texture).applying(C7UnpremultiplyAlpha())
            .withSamplerDescriptor(.init(minFilter: .nearest, magFilter: .nearest))
            .applying(C7Brightness(brightness: 0.1))
        let actual = try NeighborhoodTestImage.read(node.makeTexture())
        let frame = try node.makeFrame()
        let expected = try NeighborhoodTestImage.read(frame.texture)
        for (value, reference) in zip(actual, expected) { XCTAssertEqual(value, reference, accuracy: 0.001) }
        XCTAssertEqual(frame.alphaType, .premultiplied)
    }

    func testExplicitColorOutputMatchesColorManagedReference() async throws {
        let source = try fixture()
        let reference = try referenceBytes(source)
        let io = HarbethIO(element: source, filters: [])
        let sync = try io.output(outputColorSpace: .sRGB)
        let async = try await io.transmitOutput(outputColorSpace: .sRGB)
        let node = ImageNode.cgImage(source)
        let syncFrame = try node.makeFrame(outputColorSpace: .sRGB)
        let asyncFrame = try await node.makeFrameAsync(outputColorSpace: .sRGB)
        for image in [sync, async, try XCTUnwrap(syncFrame.texture.c7.toCGImage()),
                      try XCTUnwrap(asyncFrame.texture.c7.toCGImage())] {
            let values = try XCTUnwrap(image.dataProvider?.data) as Data
            for (value, expected) in zip(values, reference) {
                XCTAssertEqual(Int(value), Int(expected), accuracy: 2)
            }
        }
        XCTAssertEqual(sync.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertEqual(syncFrame.outputColorSpaceContract, .sRGB)
        XCTAssertEqual(syncFrame.metadata["outputColorSpace"], "sRGB")
    }

    func testExplicitColorOutputSupportsImagesAndImageBuffers() async throws {
        let source = try fixture()
        let reference = try referenceBytes(source)
        let image = try await HarbethIO(element: C7Image(cgImage: source), filters: []).transmitOutput(outputColorSpace: .sRGB)
        let ci = try await HarbethIO(element: CIImage(cgImage: source), filters: []).transmitOutput(outputColorSpace: .sRGB)
        XCTAssertEqual(image.c7.toCGImage()?.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertEqual(ci.colorSpace?.name, CGColorSpace.sRGB)
        let input = try ImageNode.cgImage(source).makeFrame().makePixelBuffer(pixelFormatType: kCVPixelFormatType_32BGRA)
        let sync = try HarbethIO(element: input, filters: []).output(outputColorSpace: .sRGB)
        let async = try await HarbethIO(element: input, filters: []).transmitOutput(outputColorSpace: .sRGB)
        for buffer in [sync, async] {
            XCTAssertEqual(buffer.c7.contract.attachmentColorSpace?.gamut, .sRGB)
            let cg = try XCTUnwrap(buffer.c7.toCGImage())
            let values = try XCTUnwrap(cg.dataProvider?.data) as Data
            // Core Video返回BGRA，统一通过纹理读回RGBA。
            let rgba = try TextureLoader(with: cg).texture.c7.toCGImage()
            let bytes = try XCTUnwrap(rgba?.dataProvider?.data) as Data
            XCTAssertFalse(values.isEmpty)
            for (actual, expected) in zip(bytes, reference) { XCTAssertEqual(Int(actual), Int(expected), accuracy: 2) }
        }
    }

    private func sourceFrame(_ texture: MTLTexture, generation: UInt64) -> RenderedFrame {
        RenderedFrame(texture: texture, outputColorSpaceContract: .sRGB, alphaType: .premultiplied,
            profile: .stablePreview, generation: generation, identifier: "reused")
    }

    private func fixture() throws -> CGImage {
        try RGBA8ImageBuffer(width: 1, height: 1, bytes: [200, 65, 90, 255],
            colorSpace: XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))).makeCGImage()
    }

    private func referenceBytes(_ image: CGImage) throws -> [UInt8] {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 4))
    }
}
