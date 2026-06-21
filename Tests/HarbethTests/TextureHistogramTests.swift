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

    func testRGBA8TextureGPUHistogramCountsExpectedBins() throws {
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

        let histogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins.reduce(0, +), 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[3], 1)
    }

    func testRGBA8TextureHistogramCanRestrictToRegion() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 2,
            height: 2,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                0, 255, 0, 255,
                0, 0, 255, 255
            ]
        )

        let histogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                region: MTLRegionMake2D(1, 0, 1, 2)
            )
        )

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins.reduce(0, +), 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[3], 1)
    }

    func testRGBA8TextureGPULuminanceHistogramCountsExpectedBins() throws {
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

        let histogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .luminance,
                bins: 256,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(histogram.channel, .luminance)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[255], 1)
    }

    func testRGBA8TextureHistogramCanRestrictToMaskCoverage() throws {
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
        let mask = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                255, 0, 0, 255,
                0, 0, 0, 255
            ]
        )

        let histogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                mask: MaskDescriptor(texture: mask, component: .red),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(histogram.bins, [1, 0, 0, 0])
    }

    func testRGBA8TextureStatisticsCanRestrictToMaskCoverage() throws {
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
        let mask = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )

        let statistics = try XCTUnwrap(
            texture.c7.makeStatistics(
                mask: MaskDescriptor(texture: mask, component: .red)
            )
        )

        XCTAssertEqual(statistics.sampleCount, 1)
        XCTAssertEqual(statistics.meanRed, 1, accuracy: 0.0001)
        XCTAssertEqual(statistics.meanLuminance, 0.2126, accuracy: 0.0001)
        XCTAssertEqual(statistics.minimumLuminance, 0.2126, accuracy: 0.0001)
        XCTAssertEqual(statistics.maximumLuminance, 0.2126, accuracy: 0.0001)
    }

    func testRGBA8TextureStatisticsSupportsUnifiedAnalysisScope() throws {
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
        let mask = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )

        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))
        let statistics = try XCTUnwrap(texture.c7.makeStatistics(scope: scope))

        XCTAssertEqual(statistics.sampleCount, 1)
        XCTAssertEqual(statistics.meanRed, 1, accuracy: 0.0001)
    }

    func testTextureAnalysisScopeFingerprintTracksRegionMaskAndThreshold() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let mask = try makeTexture(
            width: 1,
            height: 1,
            bytes: [255, 0, 0, 255]
        )

        let base = TextureAnalysisScope(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mask: MaskDescriptor(texture: mask, component: .red),
            coverageThreshold: 0.5
        )
        let same = TextureAnalysisScope(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mask: MaskDescriptor(texture: mask, component: .red),
            coverageThreshold: 0.5
        )
        let changedThreshold = TextureAnalysisScope(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mask: MaskDescriptor(texture: mask, component: .red),
            coverageThreshold: 0.75
        )

        XCTAssertEqual(base, same)
        XCTAssertEqual(base.fingerprint, same.fingerprint)
        XCTAssertNotEqual(base.fingerprint, changedThreshold.fingerprint)
    }

    func testTextureCanRenderGPUHistogramAttachment() throws {
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

        let output = try XCTUnwrap(
            texture.c7.renderHistogramAttachment(
                channel: .red,
                bins: 4,
                height: 16,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(output.histogram.channel, .red)
        XCTAssertEqual(output.histogram.bins.reduce(0, +), 2)
        XCTAssertEqual(output.attachment.semantic, .histogram)
        XCTAssertEqual(output.attachment.pixelFormat, .rgba8Unorm)
        XCTAssertNotNil(output.makeCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()))
    }

    func testTextureCanRenderGPUHistogramAttachmentForRegion() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 2,
            height: 2,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                0, 255, 0, 255,
                0, 0, 255, 255
            ]
        )

        let output = try XCTUnwrap(
            texture.c7.renderHistogramAttachment(
                channel: .red,
                bins: 4,
                height: 16,
                region: MTLRegionMake2D(1, 0, 1, 2),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(output.histogram.channel, .red)
        XCTAssertEqual(output.histogram.totalSampleCount, 2)
        XCTAssertEqual(output.histogram.bins.reduce(0, +), 2)
        XCTAssertEqual(output.histogram.bins[0], 1)
        XCTAssertEqual(output.histogram.bins[3], 1)
    }

    func testTextureCanRenderHistogramAttachmentForMaskCoverage() throws {
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
        let mask = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )

        let output = try XCTUnwrap(
            texture.c7.renderHistogramAttachment(
                channel: .red,
                bins: 4,
                height: 16,
                mask: MaskDescriptor(texture: mask, component: .red),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(output.histogram.channel, .red)
        XCTAssertEqual(output.histogram.totalSampleCount, 1)
        XCTAssertEqual(output.histogram.bins, [0, 0, 0, 1])
        XCTAssertNotNil(output.makeCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()))
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

    func testRenderedAttachmentSetCanBuildAnalysisBundleForAllAttachments() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let primary = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )
        let analysis = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 255, 255, 255
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
                    index: 0,
                    semantic: .primaryColor,
                    texture: primary,
                    debugPolicy: contract.attachments[0].debugPolicy
                ),
                RenderedAttachment(
                    index: 1,
                    semantic: .analysis,
                    texture: analysis,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        let bundle = output.makeAnalysisBundle(bins: 4, histogramHeight: 16, preferredMethod: .gpuMPS)

        XCTAssertEqual(bundle.analyses.count, 2)
        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "analysis"])
        XCTAssertEqual(bundle.primary?.attachment.semantic, .primaryColor)
        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 2)
        XCTAssertEqual(bundle.analysis(for: .analysis)?.histogram?.channel, .red)
        XCTAssertEqual(bundle.analysis(for: .analysis)?.histogram?.bins, [1, 0, 0, 1])
        XCTAssertTrue(bundle.analysisScopeFingerprint?.contains("region=none") == true)
        XCTAssertNotNil(bundle.analysis(for: .analysis)?.makeHistogramCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()))
    }

    func testRenderedAttachmentSetAnalysisBundleCanRestrictToMaskCoverage() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let primary = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )
        let analysis = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 255, 255, 255
            ]
        )
        let mask = try makeTexture(
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
                    index: 0,
                    semantic: .primaryColor,
                    texture: primary,
                    debugPolicy: contract.attachments[0].debugPolicy
                ),
                RenderedAttachment(
                    index: 1,
                    semantic: .analysis,
                    texture: analysis,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        let bundle = output.makeAnalysisBundle(
            bins: 4,
            histogramHeight: 16,
            mask: MaskDescriptor(texture: mask, component: .red),
            preferredMethod: .gpuMPS
        )

        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.primary?.histogram?.bins, [0, 1, 0, 0])
        XCTAssertEqual(bundle.primary?.statistics?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.primary?.statistics).meanRed), 1, accuracy: 0.0001)
        XCTAssertEqual(bundle.analysis(for: .analysis)?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .analysis)?.histogram?.bins.reduce(0, +), 1)
        XCTAssertEqual(bundle.analysis(for: .analysis)?.statistics?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.analysis(for: .analysis)?.statistics).meanLuminance), 1, accuracy: 0.0001)
    }

    func testRenderedAttachmentSetAnalysisBundleSupportsUnifiedAnalysisScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let primary = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ]
        )
        let analysis = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 255, 255, 255
            ]
        )
        let mask = try makeTexture(
            width: 2,
            height: 1,
            bytes: [
                255, 0, 0, 255,
                0, 0, 0, 255
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
                    index: 0,
                    semantic: .primaryColor,
                    texture: primary,
                    debugPolicy: contract.attachments[0].debugPolicy
                ),
                RenderedAttachment(
                    index: 1,
                    semantic: .analysis,
                    texture: analysis,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        let bundle = output.makeAnalysisBundle(
            bins: 4,
            histogramHeight: 16,
            scope: TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red)),
            preferredMethod: .gpuMPS
        )

        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.primary?.statistics?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.analysis(for: .analysis)?.statistics).meanLuminance), 0, accuracy: 0.0001)
        XCTAssertEqual(bundle.analysisScopeFingerprint, TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red)).fingerprint)
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
