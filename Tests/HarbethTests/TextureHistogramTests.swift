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

    func testTextureAnalysisScopePointBuildsNeighborhoodRegion() {
        let scope = TextureAnalysisScope.point(x: 4, y: 3, radius: 1)

        XCTAssertEqual(scope.region?.origin.x, 3)
        XCTAssertEqual(scope.region?.origin.y, 2)
        XCTAssertEqual(scope.region?.size.width, 3)
        XCTAssertEqual(scope.region?.size.height, 3)
    }

    func testRGBA8TextureColorProbeCanSamplePointNeighborhood() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                255, 255, 255, 255
            ]
        )

        let probe = try XCTUnwrap(
            texture.c7.makeColorProbe(x: 1, y: 0, radius: 1)
        )

        XCTAssertEqual(probe.region.origin.x, 0)
        XCTAssertEqual(probe.region.size.width, 3)
        XCTAssertEqual(probe.sampleCount, 3)
        XCTAssertEqual(probe.meanColor8.x, 170)
        XCTAssertEqual(probe.meanColor8.y, 85)
        XCTAssertEqual(probe.meanColor8.z, 85)
    }

    func testHarbethIOAnalysisBundleCarriesColorProbe() throws {
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

        let bundle = try HarbethIO(element: texture, filters: [])
            .renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                preferredMethod: .cpuReadback
        )

        XCTAssertEqual(bundle.colorProbe?.sampleCount, 2)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.colorProbe).meanLuminance), 0.1063, accuracy: 0.0001)
        XCTAssertEqual(bundle.colorProbe?.region.size.width, 2)
    }

    func testHarbethIOAnalysisBundleCanRestrictToLuminanceRangeScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                255, 255, 255, 255
            ]
        )
        let scope = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: 0.15, maximum: 0.25)
        )

        let bundle = try HarbethIO(element: texture, filters: [])
            .renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
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

    func testTextureAnalysisScopeFingerprintTracksLuminanceRange() {
        let base = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: 0.2, maximum: 0.4)
        )
        let same = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: 0.2, maximum: 0.4)
        )
        let changed = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: 0.4, maximum: 0.8)
        )

        XCTAssertEqual(base, same)
        XCTAssertNotEqual(base.fingerprint, changed.fingerprint)
        XCTAssertTrue(base.fingerprint.contains("luminance=min=0.2000|max=0.4000"))
    }

    func testTextureAnalysisScopeToneBandMapsToExpectedLuminanceRange() throws {
        let highlights = try XCTUnwrap(TextureAnalysisScope.toneBand(.highlights).luminanceRange)
        let midtones = try XCTUnwrap(TextureAnalysisScope.toneBand(.midtones).luminanceRange)

        XCTAssertEqual(highlights.minimum, 0.66, accuracy: 0.0001)
        XCTAssertEqual(highlights.maximum, 1.0, accuracy: 0.0001)
        XCTAssertEqual(midtones.minimum, 0.2, accuracy: 0.0001)
        XCTAssertEqual(midtones.maximum, 0.8, accuracy: 0.0001)
    }

    func testTextureAnalysisScopeFingerprintTracksColorRange() {
        let base = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )
        let same = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )
        let changed = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.25, maximum: 0.45),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        XCTAssertEqual(base, same)
        XCTAssertNotEqual(base.fingerprint, changed.fingerprint)
        XCTAssertTrue(base.fingerprint.contains("color=hue=min=0.9500|max=0.0500|wrap=1"))
    }

    func testRGBA8TextureHistogramCanRestrictToLuminanceRange() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                255, 255, 255, 255
            ]
        )
        let scope = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: 0.15, maximum: 0.25)
        )

        let histogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                scope: scope
            )
        )

        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(histogram.bins, [0, 0, 0, 1])
    }

    func testRGBA8TextureStatisticsCanRestrictToLuminanceRange() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                255, 255, 255, 255
            ]
        )
        let scope = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: 0.15, maximum: 0.25)
        )

        let statistics = try XCTUnwrap(texture.c7.makeStatistics(scope: scope))
        let probe = try XCTUnwrap(texture.c7.makeColorProbe(scope: scope))

        XCTAssertEqual(statistics.sampleCount, 1)
        XCTAssertEqual(statistics.meanRed, 1, accuracy: 0.0001)
        XCTAssertEqual(Double(probe.meanLuminance), 0.2126, accuracy: 0.0001)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(probe.meanColor8.y, 0)
    }

    func testRGBA8TextureHistogramCanRestrictToColorRange() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                255, 0, 0, 255,
                0, 255, 0, 255,
                255, 255, 255, 255
            ]
        )
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let histogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                scope: scope
            )
        )
        let statistics = try XCTUnwrap(texture.c7.makeStatistics(scope: scope))
        let probe = try XCTUnwrap(texture.c7.makeColorProbe(scope: scope))

        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(histogram.bins, [0, 0, 0, 1])
        XCTAssertEqual(statistics.sampleCount, 1)
        XCTAssertEqual(probe.sampleCount, 1)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(probe.meanColor8.y, 0)
        XCTAssertEqual(probe.meanColor8.z, 0)
    }

    func testTextureAnalysisValueRangeAffectsHistogramBinning() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                128, 128, 128, 255,
                64, 64, 64, 255
            ]
        )
        let defaultHistogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4
            )
        )
        let narrowRangeHistogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                valueRange: TextureAnalysisValueRange(minimum: 0.3, maximum: 0.6)
            )
        )

        XCTAssertEqual(defaultHistogram.totalSampleCount, 3)
        XCTAssertEqual(defaultHistogram.bins, [1, 1, 1, 0])
        XCTAssertEqual(narrowRangeHistogram.totalSampleCount, 3)
        XCTAssertEqual(narrowRangeHistogram.bins, [2, 0, 1, 0])
        XCTAssertNotEqual(defaultHistogram.valueRange, narrowRangeHistogram.valueRange)
    }

    func testTextureAnalysisScopeFingerprintTracksValueRange() {
        let base = TextureAnalysisScope(valueRange: TextureAnalysisValueRange(minimum: 0.2, maximum: 0.8))
        let same = TextureAnalysisScope(valueRange: TextureAnalysisValueRange(minimum: 0.2, maximum: 0.8))
        let changed = TextureAnalysisScope(valueRange: TextureAnalysisValueRange(minimum: 0.4, maximum: 0.6))

        XCTAssertEqual(base, same)
        XCTAssertEqual(base.fingerprint, same.fingerprint)
        XCTAssertNotEqual(base.fingerprint, changed.fingerprint)
        XCTAssertTrue(base.fingerprint.contains("valueRange=min=0.2000|max=0.8000"))
        XCTAssertEqual(base.valueRange, TextureAnalysisValueRange(minimum: 0.2, maximum: 0.8))
    }

    func testR16FloatTextureHistogramCanRestrictToValueRange() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeFloatTexture(
            width: 3,
            height: 1,
            values: [
                Float16(0.0),
                Float16(0.2),
                Float16(0.8)
            ]
        )
        let defaultHistogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4
            )
        )
        let narrowRangeHistogram = try XCTUnwrap(
            texture.c7.makeHistogram(
                channel: .red,
                bins: 4,
                valueRange: TextureAnalysisValueRange(minimum: 0.3, maximum: 0.6)
            )
        )

        XCTAssertEqual(defaultHistogram.totalSampleCount, 3)
        XCTAssertEqual(defaultHistogram.bins, [1, 1, 1, 0])
        XCTAssertEqual(narrowRangeHistogram.totalSampleCount, 3)
        XCTAssertEqual(narrowRangeHistogram.bins, [2, 0, 0, 1])
        XCTAssertEqual(defaultHistogram.valueRange, .normalized)
        XCTAssertEqual(narrowRangeHistogram.valueRange, TextureAnalysisValueRange(minimum: 0.3, maximum: 0.6))
    }

    func testFloatTextureStatisticsPreserveExtendedStorageValues() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let scalar = try makeFloatTexture(width: 2, height: 1, values: [Float16(0.5), Float16(2.0)])
        let scalarStatistics = try XCTUnwrap(scalar.c7.makeStatistics())

        XCTAssertEqual(scalarStatistics.pixelFormat.metalPixelFormat, .r16Float)
        XCTAssertEqual(scalarStatistics.componentDomain, .textureStorage)
        XCTAssertEqual(scalarStatistics.meanRed, 1.25, accuracy: 0.001)
        XCTAssertEqual(scalarStatistics.meanGreen, 1.25, accuracy: 0.001)
        XCTAssertEqual(scalarStatistics.meanBlue, 1.25, accuracy: 0.001)
        XCTAssertEqual(scalarStatistics.meanAlpha, 1, accuracy: 0.001)
        XCTAssertEqual(scalarStatistics.maximumLuminance, 2, accuracy: 0.001)

        let rgba = try makeRGBA16FloatTexture(
            width: 2,
            height: 1,
            values: [
                SIMD4<Float16>(2, 1, 0.5, 1),
                SIMD4<Float16>(4, 2, 1, 0.5)
            ]
        )
        let statistics = try XCTUnwrap(rgba.c7.makeStatistics())
        let histogram = try XCTUnwrap(
            rgba.c7.makeHistogram(
                channel: .red,
                bins: 5,
                valueRange: TextureAnalysisValueRange(minimum: 0, maximum: 4)
            )
        )

        XCTAssertEqual(statistics.pixelFormat.metalPixelFormat, .rgba16Float)
        XCTAssertEqual(statistics.meanRed, 3, accuracy: 0.001)
        XCTAssertEqual(statistics.meanGreen, 1.5, accuracy: 0.001)
        XCTAssertEqual(statistics.meanBlue, 0.75, accuracy: 0.001)
        XCTAssertEqual(statistics.meanAlpha, 0.75, accuracy: 0.001)
        XCTAssertEqual(histogram.pixelFormat.metalPixelFormat, .rgba16Float)
        XCTAssertEqual(histogram.bins, [0, 0, 1, 0, 1])
    }

    func testHarbethIOAnalysisBundleCanRestrictToToneBandScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                0, 0, 0, 255,
                255, 0, 0, 255,
                255, 255, 255, 255
            ]
        )

        let bundle = try HarbethIO(element: texture, filters: [])
            .renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: .toneBand(.highlights),
                preferredMethod: .cpuReadback
            )

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.y, 255)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.z, 255)
    }

    func testHarbethIOAnalysisBundleCanRestrictToColorRangeScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try makeTexture(
            width: 3,
            height: 1,
            bytes: [
                255, 0, 0, 255,
                0, 255, 0, 255,
                255, 255, 255, 255
            ]
        )
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let bundle = try HarbethIO(element: texture, filters: [])
            .renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.y, 0)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.z, 0)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
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
        XCTAssertEqual(bundle.primary?.colorProbe?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.analysis(for: .analysis)?.statistics).meanLuminance), 0, accuracy: 0.0001)
        XCTAssertEqual(bundle.analysis(for: .analysis)?.colorProbe?.meanColor8.x, 0)
        XCTAssertEqual(bundle.analysisScopeFingerprint, TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red)).fingerprint)
    }

    func testRenderedAttachmentAnalysisBundleSummaryCarriesStableAnalysisMetadata() throws {
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
        let summary = bundle.summary

        XCTAssertEqual(summary.attachmentLabels, ["primaryColor", "analysis"])
        XCTAssertEqual(summary.analyses.count, 2)
        XCTAssertEqual(summary.analyses.first?.semantic, .primaryColor)
        XCTAssertEqual(summary.analyses.first?.histogramChannel, .luminance)
        XCTAssertEqual(summary.analyses.first?.histogramTotalSampleCount, 2)
        XCTAssertTrue(summary.fingerprint.contains("labels=primaryColor,analysis"))
    }

    func testRenderedAttachmentAnalysisBundleJSONUsesSummarySurface() throws {
        let primary = try makeTexture(
            width: 1,
            height: 1,
            bytes: [255, 255, 255, 255]
        )
        let analysis = try makeTexture(
            width: 1,
            height: 1,
            bytes: [255, 255, 255, 255]
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
            scope: TextureAnalysisScope.region(MTLRegionMake2D(0, 0, 1, 1)),
            preferredMethod: .gpuMPS
        )

        let string = try bundle.jsonString(prettyPrinted: true, sortedKeys: true)

        XCTAssertTrue(string.contains("\"attachmentLabels\""))
        XCTAssertTrue(string.contains("\"analysisScopeFingerprint\""))
        XCTAssertTrue(string.contains("\"primaryColor\""))
        XCTAssertTrue(string.contains("\"analysis\""))
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
        TextureLoader.replaceTexture(
            texture,
            region: MTLRegionMake2D(0, 0, width, height),
            bytes: bytes,
            packedBytesPerRow: width * 4
        )
        return texture
    }

    private func makeFloatTexture(width: Int, height: Int, values: [Float16]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [
                .texturePixelFormat: MTLPixelFormat.r16Float,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
            ],
            identifier: "TextureHistogramTests"
        )
        values.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * MemoryLayout<Float16>.stride
            )
        }
        return texture
    }

    private func makeRGBA16FloatTexture(width: Int, height: Int, values: [SIMD4<Float16>]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [
                .texturePixelFormat: MTLPixelFormat.rgba16Float,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
            ],
            identifier: "TextureHistogramTests.RGBA16Float"
        )
        values.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * MemoryLayout<SIMD4<Float16>>.stride
            )
        }
        return texture
    }
}
