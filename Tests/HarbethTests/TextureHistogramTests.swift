import XCTest
import CoreGraphics
import Metal
@testable import Harbeth

final class TextureHistogramTests: XCTestCase {

    func testRGBA8TextureLuminanceHistogramCountsExpectedBins() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 255, 255, 255
            ]
        )

        let histogram = try XCTUnwrap(texture.c7.makeHistogram())

        XCTAssertEqual(histogram.channel, .luminance)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.binCount, 256)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[255], 1)
        XCTAssertEqual(histogram.peakCount, 1)
        XCTAssertNotNil(histogram.makePreviewCGImage(height: 16))
    }

    func testRenderedAttachmentSetCanMaterializeHistogramFromAnalysisSemantic() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )
        let contract = RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [.analysis(index: 1, pixelFormat: .rgba8Unorm)]
        )
        let output = RenderedAttachmentSet(
            outputContract: contract,
            attachments: [
                RenderedAttachment(
                    index: 1,
                    semantic: .analysis,
                    texture: texture,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        let histogram = try XCTUnwrap(output.makeHistogram(for: .analysis, channel: .red, bins: 4))

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins.reduce(0, +), 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[3], 1)
    }

    func testRenderedAttachmentSetUsesLuminanceHistogramChannelByDefaultForHistogramSemantic() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 1,
            height: 1,
            bytes: [
                128, 128, 128, 255
            ]
        )
        let contract = RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [.histogram(index: 1, pixelFormat: .rgba8Unorm)]
        )
        let output = RenderedAttachmentSet(
            outputContract: contract,
            attachments: [
                RenderedAttachment(
                    index: 1,
                    semantic: .histogram,
                    texture: texture,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        let histogram = try XCTUnwrap(output.makeHistogram(for: .histogram))

        XCTAssertEqual(histogram.channel, .luminance)
        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(histogram.bins.reduce(0, +), 1)
        XCTAssertNotNil(histogram.makePreviewCGImage())
    }

    private func makeTexture(width: Int,
                             height: Int,
                             bytes: [UInt8]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [
                .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
            ],
            identifier: "TextureHistogramTests"
        )
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return texture
    }
}
