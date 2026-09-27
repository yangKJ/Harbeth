import Metal
import XCTest
@testable import Harbeth

final class FilterPrimitiveCoverageTests: XCTestCase {

    func testToneMappingSanitizesParametersAndDeclaresSDROrEDRContract() {
        let sanitized = C7ToneMapping(
            inputNitsPerUnit: .nan,
            sourcePeakNits: -.infinity,
            targetReferenceWhiteNits: 0,
            targetPeakNits: .nan,
            shoulderStrength: .infinity,
            highlightDesaturation: -1
        )
        let edr = C7ToneMapping(
            inputNitsPerUnit: 1_000,
            sourcePeakNits: 1_000,
            targetReferenceWhiteNits: 203,
            targetPeakNits: 400
        )

        XCTAssertEqual(sanitized.inputNitsPerUnit, 1_000)
        XCTAssertEqual(sanitized.sourcePeakNits, 1_000)
        XCTAssertEqual(sanitized.targetReferenceWhiteNits, 100)
        XCTAssertEqual(sanitized.targetPeakNits, 100)
        XCTAssertEqual(sanitized.shoulderStrength, 4)
        XCTAssertEqual(sanitized.highlightDesaturation, 0)
        XCTAssertEqual(sanitized.kernelPixelContract.dynamicRangeBehavior, .toneMapsToSDR)
        XCTAssertEqual(edr.kernelPixelContract.dynamicRangeBehavior, .toneMapsToEDR)
        XCTAssertTrue(edr.kernelPixelContract.dynamicRangeBehavior.isExtendedRangeSafe)
        XCTAssertEqual(edr.kernelPixelContract.inputAlphaExpectation, .premultiplied)
        XCTAssertEqual(edr.kernelPixelContract.outputAlpha, .premultiplied)
        XCTAssertEqual(edr.memoryAccessPattern, .point)
    }

    func testToneMappingMapsReferenceWhiteToOneAndPreservesAlpha() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [0.005, 0.005, 0.005, 0.5])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7ToneMapping(
                inputNitsPerUnit: 10_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 100,
                targetPeakNits: 100
            )
        ).output()
        let pixel = try rgba16FloatPixels(in: output)

        XCTAssertEqual(pixel[0], 0.5, accuracy: 0.01)
        XCTAssertEqual(pixel[1], 0.5, accuracy: 0.01)
        XCTAssertEqual(pixel[2], 0.5, accuracy: 0.01)
        XCTAssertEqual(pixel[3], 0.5, accuracy: 0.01)
    }

    func testToneMappingKeepsExplicitEDRHeadroom() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [0.04, 0.04, 0.04, 0.4])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7ToneMapping(
                inputNitsPerUnit: 10_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 203,
                targetPeakNits: 400,
                highlightDesaturation: 0
            )
        ).output()
        let pixel = try rgba16FloatPixels(in: output)
        let expectedPeak = Float(400.0 / 203.0)

        XCTAssertEqual(pixel[0], expectedPeak * 0.4, accuracy: 0.02)
        XCTAssertEqual(pixel[1], expectedPeak * 0.4, accuracy: 0.02)
        XCTAssertEqual(pixel[2], expectedPeak * 0.4, accuracy: 0.02)
        XCTAssertEqual(pixel[3], 0.4, accuracy: 0.01)
    }

    func testToneMappingCanonicalizesTransparentPixels() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [3, 2, 1, 0])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7ToneMapping(
                inputNitsPerUnit: 1_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 203,
                targetPeakNits: 400
            )
        ).output()

        XCTAssertEqual(try rgba16FloatPixels(in: output), [0, 0, 0, 0])
    }

    func testDisplacementMapMovesPixelsWithSignedPixelFlow() throws {
        let source = try makeRGBA8Texture(
            width: 3,
            pixels: [
                255, 0, 0, 255,
                0, 255, 0, 200,
                0, 0, 255, 128
            ]
        )
        let flow = try makeRGBA16FloatTexture(
            width: 3,
            pixels: Array(repeating: [1, 0, 0, 1], count: 3).flatMap { $0 }
        )
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7DisplacementMap(
                displacementTexture: flow,
                samplingMode: .nearest,
                edgeMode: .clamp
            )
        ).output()

        XCTAssertEqual(
            try rgba8Pixels(in: output),
            [
                0, 255, 0, 200,
                0, 0, 255, 128,
                0, 0, 255, 128
            ]
        )
    }

    func testNormalizedDisplacementNeutralValueIsIdentity() throws {
        let sourcePixels: [UInt8] = [
            12, 34, 56, 78,
            90, 123, 145, 167
        ]
        let source = try makeRGBA8Texture(width: 2, pixels: sourcePixels)
        let neutralFlow = try makeRGBA16FloatTexture(
            width: 2,
            pixels: Array(repeating: [0.5, 0.5, 0, 1], count: 2).flatMap { $0 }
        )
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7DisplacementMap(
                displacementTexture: neutralFlow,
                encoding: .normalized,
                samplingMode: .nearest,
                edgeMode: .clamp
            )
        ).output()

        XCTAssertEqual(try rgba8Pixels(in: output), sourcePixels)
    }

    func testZeroConfidenceProtectsOriginalFromDisplacement() throws {
        let sourcePixels: [UInt8] = [
            255, 0, 0, 255,
            0, 255, 0, 128
        ]
        let source = try makeRGBA8Texture(width: 2, pixels: sourcePixels)
        let flow = try makeRGBA16FloatTexture(
            width: 2,
            pixels: Array(repeating: [1, 0, 0, 1], count: 2).flatMap { $0 }
        )
        let confidence = try makeRGBA16FloatTexture(
            width: 2,
            pixels: Array(repeating: [0, 0, 0, 1], count: 2).flatMap { $0 }
        )
        let filter = C7DisplacementMap(
            displacementTexture: flow,
            confidenceTexture: confidence,
            samplingMode: .nearest,
            edgeMode: .clamp
        )
        let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()

        XCTAssertEqual(try rgba8Pixels(in: output), sourcePixels)
        XCTAssertEqual(filter.otherInputTextures.count, 2)
        XCTAssertEqual(filter.makeKernelExecutionPlan(inputSize: C7Size(width: 2, height: 1)).inputTextureCount, 3)
        XCTAssertEqual(filter.memoryAccessPattern, .multiTexture)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .dynamic)
        XCTAssertEqual(filter.kernelPixelContract.coordinateDependency, .transformed)
        XCTAssertFalse(filter.kernelPixelContract.canAutoTile)
    }

    func testRecentProfessionalColorPrimitivesKeepIdentityAndAlpha() throws {
        let sourcePixels: [UInt8] = [71, 133, 201, 117]
        let source = try makeRGBA8Texture(width: 1, pixels: sourcePixels)
        let filters: [C7FilterProtocol] = [
            C7SelectiveHSL(),
            C7ColorGrading(),
            C7WhitesBlacks()
        ]

        for filter in filters {
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            let pixel = try rgba8Pixels(in: output)
            for channel in 0..<4 {
                XCTAssertEqual(pixel[channel], sourcePixels[channel], accuracy: 1)
            }
        }
    }

    func testCurvesMultiPointSegmentsMapActualPixelsContinuously() throws {
        let sourceValues: [UInt8] = [63, 64, 65, 127, 128, 191, 192, 193]
        let sourcePixels = sourceValues.flatMap { [$0, $0, $0, UInt8.max] }
        let source = try makeRGBA8Texture(width: sourceValues.count, pixels: sourcePixels)
        let points = [
            C7Point2D(x: 0, y: 0),
            C7Point2D(x: 0.25, y: 0.75),
            C7Point2D(x: 0.75, y: 0.25),
            C7Point2D(x: 1, y: 1)
        ]
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7Curves(rgbPoints: points, interpolation: .linear)
        ).output()
        let outputPixels = try rgba8Pixels(in: output)
        let outputValues = stride(from: 0, to: outputPixels.count, by: 4).map { outputPixels[$0] }

        XCTAssertEqual(outputValues[1], 191, accuracy: 2)
        XCTAssertEqual(outputValues[4], 127, accuracy: 2)
        XCTAssertEqual(outputValues[6], 64, accuracy: 2)
        XCTAssertLessThanOrEqual(abs(Int(outputValues[0]) - Int(outputValues[1])), 4)
        XCTAssertLessThanOrEqual(abs(Int(outputValues[1]) - Int(outputValues[2])), 4)
        XCTAssertLessThanOrEqual(abs(Int(outputValues[5]) - Int(outputValues[6])), 4)
        XCTAssertLessThanOrEqual(abs(Int(outputValues[6]) - Int(outputValues[7])), 4)
        for index in stride(from: 3, to: outputPixels.count, by: 4) {
            XCTAssertEqual(outputPixels[index], UInt8.max)
        }
    }

    func testLegacyCurvesKeepPreviouslyPersistedMultiPointRendering() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [77, 77, 77, 255])
        let points = [
            C7Point2D(x: 0, y: 0),
            C7Point2D(x: 0.3, y: 0.2),
            C7Point2D(x: 0.7, y: 0.8),
            C7Point2D(x: 1, y: 1)
        ]
        let legacy: MTLTexture = try HarbethIO(
            element: source,
            filter: C7Curves(rgbPoints: points, interpolation: .legacy)
        ).output()
        let corrected: MTLTexture = try HarbethIO(
            element: source,
            filter: C7Curves(rgbPoints: points, interpolation: .linear)
        ).output()
        let legacyValue = try rgba8Pixels(in: legacy)[0]
        let correctedValue = try rgba8Pixels(in: corrected)[0]

        XCTAssertEqual(legacyValue, 137, accuracy: 3)
        XCTAssertEqual(correctedValue, 52, accuracy: 3)
    }

    func testNeighborhoodDetailFiltersDeclareOnePixelHalo() {
        XCTAssertEqual(C7EdgeAwareSharpen(amount: 1).samplingFootprint, .neighborhood(radius: 1))
        XCTAssertEqual(C7SharpenDetail(clarity: 1).samplingFootprint, .neighborhood(radius: 1))
    }

    func testEdgeAwareSharpenKeepsUniformImageIdenticalAtCorners() throws {
        let sourcePixels: [UInt8] = Array(repeating: [128, 128, 128, 255], count: 25).flatMap { $0 }
        let source = try makeRGBA8Texture(width: 5, height: 5, pixels: sourcePixels)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7EdgeAwareSharpen(amount: 1, edgeThreshold: 0)
        ).output()

        let outputPixels = try rgba8Pixels(in: output)
        for index in stride(from: 0, to: outputPixels.count, by: 4) {
            XCTAssertEqual(outputPixels[index], 128, accuracy: 1)
            XCTAssertEqual(outputPixels[index + 1], 128, accuracy: 1)
            XCTAssertEqual(outputPixels[index + 2], 128, accuracy: 1)
            XCTAssertEqual(outputPixels[index + 3], 255)
        }
    }

    func testSharpenDetailDoesNotInventStructureOnUniformImage() throws {
        let sourcePixels: [UInt8] = Array(repeating: [128, 128, 128, 255], count: 25).flatMap { $0 }
        let source = try makeRGBA8Texture(width: 5, height: 5, pixels: sourcePixels)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SharpenDetail(sharpen: 0, clarity: 1, detail: 1)
        ).output()

        let outputPixels = try rgba8Pixels(in: output)
        for index in stride(from: 0, to: outputPixels.count, by: 4) {
            XCTAssertEqual(outputPixels[index], 128, accuracy: 1)
            XCTAssertEqual(outputPixels[index + 1], 128, accuracy: 1)
            XCTAssertEqual(outputPixels[index + 2], 128, accuracy: 1)
            XCTAssertEqual(outputPixels[index + 3], 255)
        }
    }

    func testChannelControlBlendControlsRenderedStrength() throws {
        let sourcePixels: [UInt8] = [100, 150, 200, 128]
        let source = try makeRGBA8Texture(width: 1, pixels: sourcePixels)
        let disabled: MTLTexture = try HarbethIO(
            element: source,
            filter: C7ChannelControl(red: 0.5, green: -0.5, blue: 0, alpha: 0.5, blend: 0)
        ).output()
        let applied: MTLTexture = try HarbethIO(
            element: source,
            filter: C7ChannelControl(red: 0.5, green: -0.5, blue: 0, alpha: 0.5, blend: 1)
        ).output()

        XCTAssertEqual(try rgba8Pixels(in: disabled), sourcePixels)
        let appliedPixels = try rgba8Pixels(in: applied)
        XCTAssertEqual(appliedPixels[0], 150, accuracy: 1)
        XCTAssertEqual(appliedPixels[1], 75, accuracy: 1)
        XCTAssertEqual(appliedPixels[2], 200, accuracy: 1)
        XCTAssertEqual(appliedPixels[3], 64, accuracy: 1)
    }

    func testExposureProducesOneStopGainAndPreservesAlpha() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [64, 64, 64, 123])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7Exposure(exposure: 1)
        ).output()
        let pixels = try rgba8Pixels(in: output)

        XCTAssertEqual(pixels[0], 128, accuracy: 1)
        XCTAssertEqual(pixels[1], 128, accuracy: 1)
        XCTAssertEqual(pixels[2], 128, accuracy: 1)
        XCTAssertEqual(pixels[3], 123)
    }

    func testWhiteBalanceWarmDirectionRaisesRedRelativeToBlue() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [128, 128, 128, 211])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7WhiteBalance(temperature: 6_500, tint: 0)
        ).output()
        let pixels = try rgba8Pixels(in: output)

        XCTAssertGreaterThan(pixels[0], pixels[2])
        XCTAssertEqual(pixels[3], 211)
    }

    func testSelectiveHSLRedChannelDesaturatesRedWithoutShiftingBlue() throws {
        let sourcePixels: [UInt8] = [255, 0, 0, 255, 0, 0, 255, 255]
        let source = try makeRGBA8Texture(width: 2, pixels: sourcePixels)
        var adjustments = Array(repeating: SIMD3<Float>.zero, count: C7SelectiveHSL.channelCount)
        adjustments[0] = SIMD3<Float>(0, -1, 0)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SelectiveHSL(adjustments: adjustments)
        ).output()
        let pixels = try rgba8Pixels(in: output)

        let redOutputChroma = Int(pixels[0...2].max()!) - Int(pixels[0...2].min()!)
        XCTAssertLessThanOrEqual(redOutputChroma, 8)
        XCTAssertEqual(Array(pixels[4...7]), Array(sourcePixels[4...7]))
        XCTAssertEqual(pixels[3], 255)
    }

    func testColorGradingShadowTintWeightsDarkPixelsMoreThanHighlights() throws {
        let source = try makeRGBA8Texture(
            width: 2,
            pixels: [64, 64, 64, 151, 192, 192, 192, 187]
        )
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7ColorGrading(
                shadows: SIMD3<Float>(240, 1, 0),
                blending: 0.5
            )
        ).output()
        let pixels = try rgba8Pixels(in: output)
        let darkBlueBias = Int(pixels[2]) - Int(pixels[0])
        let brightBlueBias = Int(pixels[6]) - Int(pixels[4])

        XCTAssertGreaterThan(darkBlueBias, brightBlueBias)
        XCTAssertEqual(pixels[3], 151)
        XCTAssertEqual(pixels[7], 187)
    }

    func testOutputQuantizationIsDeterministicWithoutDitherAndPreservesAlpha() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [100, 100, 100, 123])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7OutputQuantization(bitDepth: 4, pattern: .none)
        ).output()

        XCTAssertEqual(try rgba8Pixels(in: output), [102, 102, 102, 123])
    }

    private func makeRGBA8Texture(width: Int, height: Int = 1, pixels: [UInt8]) throws -> MTLTexture {
        guard pixels.count == width * height * 4 else {
            throw HarbethError.filterParameterInvalid("RGBA8 dimensions do not match the pixel count.")
        }
        let texture = try makeTexture(pixelFormat: .rgba8Unorm, width: width, height: height)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func makeRGBA16FloatTexture(width: Int, pixels: [Float16]) throws -> MTLTexture {
        guard pixels.count == width * 4 else {
            throw HarbethError.filterParameterInvalid("RGBA16Float dimensions do not match the pixel count.")
        }
        let texture = try makeTexture(pixelFormat: .rgba16Float, width: width)
        pixels.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, 1),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * 8
            )
        }
        return texture
    }

    private func makeTexture(pixelFormat: MTLPixelFormat, width: Int, height: Int = 1) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        return texture
    }

    private func rgba8Pixels(in texture: MTLTexture) throws -> [UInt8] {
        guard texture.pixelFormat == .rgba8Unorm else {
            throw HarbethError.filterParameterInvalid("Expected an RGBA8 output.")
        }
        var values = Array(repeating: UInt8.zero, count: texture.width * texture.height * 4)
        texture.getBytes(
            &values,
            bytesPerRow: texture.width * 4,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        return values
    }

    private func rgba16FloatPixels(in texture: MTLTexture) throws -> [Float] {
        guard texture.pixelFormat == .rgba16Float else {
            throw HarbethError.filterParameterInvalid("Expected an RGBA16Float output.")
        }
        var values = Array(repeating: Float16.zero, count: texture.width * 4)
        values.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, 1),
                mipmapLevel: 0
            )
        }
        return values.map(Float.init)
    }
}
