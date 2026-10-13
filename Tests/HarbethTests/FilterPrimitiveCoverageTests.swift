import Metal
import CoreGraphics
import XCTest
@testable import Harbeth

final class FilterPrimitiveCoverageTests: XCTestCase {

    func testSpatialBlurDeclaresFullImageSamplingAndSanitizesInvalidFactors() {
        let motion = C7MotionBlur(radius: .nan, blurAngle: .infinity)
        var zoom = C7ZoomBlur(radius: -.infinity)
        zoom.blurCenter = C7Point2D(x: .nan, y: 2)
        XCTAssertEqual(motion.factors, [0, 0])
        XCTAssertEqual(zoom.factors, [0, 1, 0])
        for filter in [motion as C7FilterProtocol, zoom] {
            XCTAssertEqual(filter.samplingFootprint, .dynamic)
            XCTAssertEqual(filter.kernelPixelContract.coordinateDependency, .fullImage)
            XCTAssertEqual(filter.kernelPixelContract.globalDependency, .imageDimensions)
            XCTAssertEqual(filter.kernelPixelContract.inputAlphaExpectation, .premultiplied)
            XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
            XCTAssertFalse(filter.kernelPixelContract.canAutoTile)
        }
    }

    func testSpatialBlurZeroRadiusPreservesRGBA16ThroughBothPublicEntries() throws {
        let source = try makeRGBA16FloatTexture(width: 3, pixels: [
            -0.1, 1.4, 0.2, 0.5, 0, 0, 0, 0, 0.4, 0.3, 0.2, 1
        ])
        let expected = try rgba16FloatPixels(in: source)
        for filter in [C7MotionBlur(radius: 0, blurAngle: 37) as C7FilterProtocol, C7ZoomBlur(radius: 0)] {
            let io = try HarbethIO(element: source, filter: filter).renderTexture(profile: .exportQuality)
            let node = try ImageNode.texture(source).applying(filter).makeFrame(profile: .exportQuality)
            XCTAssertEqual(try rgba16FloatPixels(in: io), expected)
            XCTAssertEqual(try rgba16FloatPixels(in: node.texture), expected)
        }
    }

    func testSpatialBlurPreservesConstantExtendedPremultipliedPixels() throws {
        let source = try makeRGBA16FloatTexture(width: 3, pixels: Array(repeating: [-0.1, 1.4, 0.2, 0.5], count: 3).flatMap { $0 })
        let expected = try rgba16FloatPixels(in: source)
        for filter in [C7MotionBlur(radius: 6, blurAngle: 37) as C7FilterProtocol, C7ZoomBlur(radius: 7)] {
            let io = try HarbethIO(element: source, filter: filter).renderTexture(profile: .exportQuality)
            let node = try ImageNode.texture(source).applying(filter).makeFrame(profile: .exportQuality)
            for output in [io, node.texture] {
                let actual = try rgba16FloatPixels(in: output)
                for (value, baseline) in zip(actual, expected) {
                    XCTAssertEqual(value, baseline, accuracy: 0.002)
                }
            }
        }
    }

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

    func testPQAndHLGTransferRoundTripPreservesSignedValuesAndAlpha() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [-0.02, 0.18, 0.75, 0.35])
        for pair in [(C7RGBTransferConversion.Mode.pqToLinear, C7RGBTransferConversion.Mode.linearToPQ),
                     (C7RGBTransferConversion.Mode.hlgToLinear, C7RGBTransferConversion.Mode.linearToHLG)] {
            let decoded: MTLTexture = try HarbethIO(element: source,
                filter: C7RGBTransferConversion(mode: pair.0)).output()
            let encoded: MTLTexture = try HarbethIO(element: decoded,
                filter: C7RGBTransferConversion(mode: pair.1)).output()
            let pixel = try rgba16FloatPixels(in: encoded)
            XCTAssertEqual(pixel[0], -0.02, accuracy: 0.01)
            XCTAssertEqual(pixel[1], 0.18, accuracy: 0.01)
            XCTAssertEqual(pixel[2], 0.75, accuracy: 0.02)
            XCTAssertEqual(pixel[3], 0.35, accuracy: 0.01)
            XCTAssertEqual(C7RGBTransferConversion(mode: pair.0).kernelPixelContract.dynamicRangeBehavior,
                           .preservesExtendedRange)
        }
    }

    func testBrightnessPreservesExtendedPixelsAndAlphaInRealMetalExecution() throws {
        let filter = C7Brightness(brightness: 0.25)
        XCTAssertEqual(filter.kernelPixelContract.workingColorSpace, .extendedLinearDisplayP3)
        XCTAssertEqual(filter.kernelPixelContract.precision, .float16)
        XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
        XCTAssertEqual(filter.kernelPixelContract.outputAlpha, .preserveInput)

        let source = try makeRGBA16FloatTexture(width: 1, pixels: [-0.5, 1.5, 0.25, 0.375])
        let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        let pixel = try rgba16FloatPixels(in: output)

        XCTAssertEqual(pixel[0], -0.25, accuracy: 0.01)
        XCTAssertEqual(pixel[1], 1.75, accuracy: 0.01)
        XCTAssertEqual(pixel[2], 0.5, accuracy: 0.01)
        XCTAssertEqual(pixel[3], 0.375, accuracy: 0.01)
    }

    func testExposurePreservesExtendedPixelsAndAlphaInRealMetalExecution() throws {
        let filter = C7Exposure(exposure: 1)
        XCTAssertEqual(filter.kernelPixelContract.workingColorSpace, .extendedLinearDisplayP3)
        XCTAssertEqual(filter.kernelPixelContract.precision, .float16)
        XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
        XCTAssertEqual(filter.kernelPixelContract.outputAlpha, .preserveInput)

        let source = try makeRGBA16FloatTexture(width: 1, pixels: [-0.5, 1.5, 0.25, 0.625])
        let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        let pixel = try rgba16FloatPixels(in: output)

        XCTAssertEqual(pixel[0], -1, accuracy: 0.01)
        XCTAssertEqual(pixel[1], 3, accuracy: 0.01)
        XCTAssertEqual(pixel[2], 0.5, accuracy: 0.01)
        XCTAssertEqual(pixel[3], 0.625, accuracy: 0.01)
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

    func testNumericLevelsGammaWorksOnStraightColorAndPreservesAlpha() throws {
        let source = try makeRGBA16FloatTexture(width: 2, pixels: [0.125, 0.25, 0.375, 0.5, 0, 0, 0, 0])
        let filter = C7LevelsAdjustment(gamma: SIMD3(repeating: 2))
        let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        let values = try rgba16FloatPixels(in: output)
        XCTAssertEqual(values[0], 0.25, accuracy: 0.002)
        XCTAssertEqual(values[1], sqrt(0.5) * 0.5, accuracy: 0.002)
        XCTAssertEqual(values[2], sqrt(0.75) * 0.5, accuracy: 0.002)
        XCTAssertEqual(values[3], 0.5)
        XCTAssertEqual(Array(values[4...7]), [0, 0, 0, 0])
        XCTAssertEqual(filter.kernelParameterBindings.count, 5)
        XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .clampsToUnitRange)
    }

    func testNumericLevelsInputOutputRangesCanInvertAndStayFinite() throws {
        let source = try makeRGBA16FloatTexture(width: 3, pixels: [0, 0, 0, 1, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1])
        let filter = C7LevelsAdjustment(inputBlack: SIMD3(repeating: 0.25), inputWhite: SIMD3(repeating: 0.75),
                                       outputBlack: SIMD3(repeating: 1), outputWhite: .zero)
        let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        let values = try rgba16FloatPixels(in: output)
        XCTAssertEqual(values[0], 1, accuracy: 0.002)
        XCTAssertEqual(values[4], 0.5, accuracy: 0.002)
        XCTAssertEqual(values[8], 0, accuracy: 0.002)
        let invalid = C7LevelsAdjustment(inputBlack: SIMD3(repeating: .nan), gamma: SIMD3(repeating: .infinity),
                                        inputWhite: .zero)
        let corrected: MTLTexture = try HarbethIO(element: source, filter: invalid).output()
        XCTAssertTrue(try rgba16FloatPixels(in: corrected).allSatisfy { $0.isFinite })
    }

    func testShapePreservingCurvesMatchKnownHermiteValuesAndBounds() {
        let points = [C7Point2D(x: 0, y: 0), C7Point2D(x: 0.5, y: 0.25), C7Point2D(x: 1, y: 1)]
        XCTAssertEqual(C7Curves.shapePreservingValue(0.25, points: points), 0.109375, accuracy: 0.000001)
        XCTAssertEqual(C7Curves.shapePreservingValue(0.75, points: points), 0.578125, accuracy: 0.000001)
        let turning = [C7Point2D(x: 0, y: 0.2), C7Point2D(x: 0.1, y: 0.9),
                       C7Point2D(x: 0.8, y: 0.1), C7Point2D(x: 1, y: 0.7)]
        for pair in zip(turning, turning.dropFirst()) {
            for step in 0...100 {
                let x = pair.0.x + (pair.1.x - pair.0.x) * Float(step) / 100
                let y = C7Curves.shapePreservingValue(x, points: turning)
                XCTAssertGreaterThanOrEqual(y, min(pair.0.y, pair.1.y) - 0.000001)
                XCTAssertLessThanOrEqual(y, max(pair.0.y, pair.1.y) + 0.000001)
            }
        }
    }

    func testShapePreservingCurveGPUTracksControlPlotAcrossAllSamples() throws {
        let points = [C7Point2D(x: 0, y: 0), C7Point2D(x: 0.1, y: 0.8),
                      C7Point2D(x: 0.7, y: 0.2), C7Point2D(x: 1, y: 1)]
        let values = (0...256).map { Float16(Float($0) / 256) }
        let texture = try makeRGBA16FloatTexture(width: values.count, pixels: values.flatMap { [$0, $0, $0, Float16(1)] })
        let output: MTLTexture = try HarbethIO(element: texture,
            filter: C7Curves(rgbPoints: points, interpolation: .shapePreserving)).output()
        let pixels = try rgba16FloatPixels(in: output)
        for (index, value) in values.enumerated() {
            let expected = C7Curves.shapePreservingValue(Float(value), points: points)
            XCTAssertEqual(pixels[index * 4], expected, accuracy: 0.002)
            XCTAssertEqual(pixels[index * 4 + 3], 1)
        }
    }

    func testCurvesCompositionOrderIsExplicitAndShaderBound() throws {
        let rgb = [C7Point2D(x: 0, y: 0), C7Point2D(x: 0.5, y: 0.25), C7Point2D(x: 1, y: 1)]
        let red = [C7Point2D(x: 0, y: 0.3), C7Point2D(x: 1, y: 0.9)]
        let texture = try makeRGBA16FloatTexture(width: 1, pixels: [0.25, 0.5, 0.75, 1])
        for mode: C7Curves.Interpolation in [.linear, .shapePreserving] {
            let filter = C7Curves(rgbPoints: rgb, redPoints: red, interpolation: mode, compositionOrder: .channelsThenRGB)
            let output: MTLTexture = try HarbethIO(element: texture, filter: filter).output()
            let expected = mode == .linear ? Float(0.225) : C7Curves.shapePreservingValue(0.45, points: rgb)
            XCTAssertEqual(try rgba16FloatPixels(in: output)[0], expected, accuracy: 0.002)
        }
        let ordered = C7Curves(rgbPoints: [C7Point2D(x: 0, y: 0), C7Point2D(x: 1, y: 0.5)], redPoints: red,
                               compositionOrder: .channelsThenRGB)
        let output: MTLTexture = try HarbethIO(element: texture, filter: ordered).output()
        XCTAssertEqual(try rgba16FloatPixels(in: output)[0], 0.225, accuracy: 0.002)
    }

    func testShapePreservingCurvesUseStraightColorsAndKeepTransparentPixelsEmpty() throws {
        let points = [C7Point2D(x: 0, y: 0.2), C7Point2D(x: 0.5, y: 0.3), C7Point2D(x: 1, y: 0.9)]
        let texture = try makeRGBA16FloatTexture(width: 2, pixels: [0.125, 0.25, 0.375, 0.5, 0, 0, 0, 0])
        let output: MTLTexture = try HarbethIO(element: texture,
            filter: C7Curves(rgbPoints: points, interpolation: .shapePreserving, compositionOrder: .channelsThenRGB)).output()
        let pixels = try rgba16FloatPixels(in: output)
        for (index, value): (Int, Float) in [Float(0.25), 0.5, 0.75].enumerated() {
            XCTAssertEqual(pixels[index], C7Curves.shapePreservingValue(value, points: points) * 0.5, accuracy: 0.002)
        }
        XCTAssertEqual(pixels[3], 0.5)
        XCTAssertEqual(Array(pixels[4...7]), [0, 0, 0, 0])
    }

    func testShapePreservingCurvesLinearExtrapolationKeepsExtendedPixels() throws {
        let texture = try makeRGBA16FloatTexture(width: 1, pixels: [-0.5, 2, 0.5, 0.4])
        let filter = C7Curves(interpolation: .shapePreserving, extrapolation: .linear, compositionOrder: .channelsThenRGB)
        let output: MTLTexture = try HarbethIO(element: texture, filter: filter).output()
        let pixels = try rgba16FloatPixels(in: output)
        for (actual, expected) in zip(pixels, [Float(-0.5), 2, 0.5, 0.4]) { XCTAssertEqual(actual, expected, accuracy: 0.002) }
        XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
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

    func testCurvesKeepSDREndpointsAndVersionHDRExtrapolation() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [-0.5, 2, 0.5, 0.4])
        let points = [C7Point2D(x: 0, y: 0), C7Point2D(x: 1, y: 1)]
        let sdr: MTLTexture = try HarbethIO(element: source,
            filter: C7Curves(rgbPoints: points, redPoints: points, greenPoints: points,
                             bluePoints: points, interpolation: .linear)).output()
        let hdrFilter = C7Curves(rgbPoints: points, redPoints: points, greenPoints: points,
                                 bluePoints: points, interpolation: .linear, extrapolation: .linear)
        let hdr: MTLTexture = try HarbethIO(element: source, filter: hdrFilter).output()
        let sdrPixel = try rgba16FloatPixels(in: sdr)
        let hdrPixel = try rgba16FloatPixels(in: hdr)

        XCTAssertEqual(sdrPixel[0], 0, accuracy: 0.01)
        XCTAssertEqual(sdrPixel[1], 1, accuracy: 0.01)
        XCTAssertEqual(hdrPixel[0], -0.5, accuracy: 0.01)
        XCTAssertEqual(hdrPixel[1], 2, accuracy: 0.01)
        XCTAssertEqual(hdrPixel[3], 0.4, accuracy: 0.01)
        XCTAssertEqual(hdrFilter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
    }

    func testLookupPoliciesPreserveExtendedPixelsWithoutChangingLegacyDefaults() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [1.5, -0.5, 0.25, 0.4])
        let oneDimensionalTexture = try makeRGBA16FloatTexture(width: 2, pixels: [
            0, 0, 0, 1, 1, 1, 1, 1
        ])
        let oneDimensional = C7LookupTable1D(lookupTexture: oneDimensionalTexture, intensity: 1,
                                              domainPolicy: .preserveOutsideDomain)
        let oneDimensionalOutput: MTLTexture = try HarbethIO(element: source, filter: oneDimensional).output()
        let oneDimensionalPixel = try rgba16FloatPixels(in: oneDimensionalOutput)
        XCTAssertEqual(oneDimensionalPixel[0], 1.5, accuracy: 0.01)
        XCTAssertEqual(oneDimensionalPixel[1], -0.5, accuracy: 0.01)
        XCTAssertEqual(oneDimensionalPixel[3], 0.4, accuracy: 0.01)
        XCTAssertEqual(C7LookupTable1D(lookupTexture: oneDimensionalTexture).domainPolicy, .clampToEdge)
        XCTAssertEqual(oneDimensional.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)

        let lookupPixels = Array(repeating: [Float16](arrayLiteral: 0, 0, 0, 1), count: 512 * 512).flatMap { $0 }
        let twoDimensionalTexture = try makeRGBA16FloatTexture(width: 512, height: 512, pixels: lookupPixels)
        let twoDimensional = C7LookupTable(lookupTexture: twoDimensionalTexture, intensity: 1,
                                            domainPolicy: .preserveOutsideDomain)
        let twoDimensionalOutput: MTLTexture = try HarbethIO(element: source, filter: twoDimensional).output()
        let twoDimensionalPixel = try rgba16FloatPixels(in: twoDimensionalOutput)
        let expected: [Float] = [1.5, -0.5, 0.25, 0.4]
        for index in 0..<4 { XCTAssertEqual(twoDimensionalPixel[index], expected[index], accuracy: 0.01) }
        XCTAssertEqual(C7LookupTable(lookupTexture: twoDimensionalTexture).domainPolicy, .legacy)
    }

    func testColorCubeVersionsDomainClampAndHDRPreservation() throws {
        var values: [Float] = []
        for blue in 0...1 { for green in 0...1 { for red in 0...1 {
            values.append(contentsOf: [Float(red), Float(green), Float(blue), 1])
        } } }
        let resource = C7ColorCube.Resource(dimension: 2,
            data: values.withUnsafeBufferPointer { Data(buffer: $0) })
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [1.5, -0.5, 0.25, 0.6])
        let legacy: MTLTexture = try HarbethIO(element: source,
            filter: C7ColorCube(cubeResource: resource)).output()
        let hdrFilter = C7ColorCube(cubeResource: resource, domainPolicy: .preserveOutsideDomain)
        let hdr: MTLTexture = try HarbethIO(element: source, filter: hdrFilter).output()
        let legacyPixel = try rgba16FloatPixels(in: legacy)
        let hdrPixel = try rgba16FloatPixels(in: hdr)
        XCTAssertEqual(legacyPixel[0], 1, accuracy: 0.01)
        XCTAssertEqual(legacyPixel[1], 0, accuracy: 0.01)
        XCTAssertEqual(hdrPixel[0], 1.5, accuracy: 0.01)
        XCTAssertEqual(hdrPixel[1], -0.5, accuracy: 0.01)
        XCTAssertEqual(hdrPixel[3], 0.6, accuracy: 0.01)
        XCTAssertEqual(hdrFilter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
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

    func testDetailSharpeningKeepsUniformExtendedRangeAndAlpha() throws {
        let pixel: [Float16] = [2, -0.25, 0.5, 0.45]
        let source = try makeRGBA16FloatTexture(width: 3, height: 3,
            pixels: Array(repeating: pixel, count: 9).flatMap { $0 })
        for filter: C7FilterProtocol in [
            C7SharpenDetail(sharpen: 1, clarity: 1, detail: 1),
            C7EdgeAwareSharpen(amount: 1, edgeThreshold: 0)
        ] {
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            let values = try rgba16FloatPixels(in: output)
            XCTAssertEqual(values[0], 2, accuracy: 0.02)
            XCTAssertEqual(values[1], -0.25, accuracy: 0.02)
            XCTAssertEqual(values[2], 0.5, accuracy: 0.02)
            XCTAssertEqual(values[3], 0.45, accuracy: 0.02)
            XCTAssertEqual(filter.kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
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
        let sourcePixels: [UInt8] = [50, 75, 100, 128]
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
        XCTAssertEqual(appliedPixels[0], 38, accuracy: 1)
        XCTAssertEqual(appliedPixels[1], 19, accuracy: 1)
        XCTAssertEqual(appliedPixels[2], 50, accuracy: 1)
        XCTAssertEqual(appliedPixels[3], 64, accuracy: 1)
    }

    func testChannelControlOpacityScalesPremultipliedPixelsThroughBothEntries() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [100, 150, 200, 255])
        for alpha: Float in [0, 0.18, 0.5, 1] {
            let filter = C7ChannelControl(alpha: alpha, blend: 1)
            let io = try HarbethIO(element: source, filter: filter).renderTexture(profile: .readbackQuality)
            let frame = try ImageNode.texture(source).applying(filter).makeFrame(profile: .readbackQuality)
            for output in [io, frame.texture] {
                let pixels = try rgba8Pixels(in: output)
                for (index, value) in [100, 150, 200, 255].enumerated() {
                    XCTAssertEqual(Int(pixels[index]), Int((Float(value) * alpha).rounded()), accuracy: 1)
                }
            }
            XCTAssertEqual(frame.alphaType, .premultiplied)
        }
    }

    func testChannelControlPartialBlendScalesExistingTransparentPixelsOnce() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [50, 75, 100, 128])
        let filter = C7ChannelControl(alpha: 0.5, blend: 0.5)
        let frame = try ImageNode.texture(source).applying(filter).makeFrame(profile: .readbackQuality)
        let output = try rgba8Pixels(in: frame.texture)
        for (index, expected) in [38, 56, 75, 96].enumerated() {
            XCTAssertEqual(Int(output[index]), expected, accuracy: 1)
        }
    }

    func testChannelControlOpacityPreservesExtendedRangeAndNegativeColor() throws {
        let source = try makeRGBA16FloatTexture(width: 1, pixels: [-0.1, 1.4, 0.2, 0.5])
        let filter = C7ChannelControl(alpha: 0.5, blend: 1)
        let frame = try ImageNode.texture(source).applying(filter).makeFrame(profile: .readbackQuality)
        let output = try rgba16FloatPixels(in: frame.texture)
        for (index, expected): (Int, Float) in [-0.05, 0.7, 0.1, 0.25].enumerated() {
            XCTAssertEqual(output[index], expected, accuracy: 0.002)
        }
    }

    func testChannelControlFramesCarryTransparentOutputFromOpaqueSource() throws {
        let data = Data([100, 150, 200, 255])
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let image = try XCTUnwrap(CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        XCTAssertEqual(ImageSource.cgImage(image).alphaType, .alphaIsOne)
        let filters: [C7FilterProtocol] = [C7ChannelControl(alpha: 0.18, blend: 1), C7Brightness(brightness: 0)]
        let node = try ImageNode.cgImage(image).applying(filters: filters).makeFrame(profile: .readbackQuality)
        let io = try FrameRenderer(source: .cgImage(image), filters: filters, profile: .readbackQuality).renderFrame()
        for frame in [node, io] {
            XCTAssertEqual(frame.alphaType, .premultiplied)
            XCTAssertEqual(try XCTUnwrap(frame.texture.c7.toCGImage(alphaType: frame.alphaType)).alphaInfo, .premultipliedLast)
        }
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

    func testOutputQuantizationRegionsMatchFullFrameThroughBothEntries() throws {
        let width = 37, height = 29
        let values = quantizationFixture(width: width, height: height)
        let source = try makeRGBA16FloatTexture(width: width, height: height, pixels: values)
        for pattern in [ImageDitherPattern.none, .ordered2x2, .ordered4x4, .ordered8x8, .interleavedGradient] {
            let base = C7OutputQuantization(bitDepth: 3, pattern: pattern, seed: 71)
            let full = try rgba16FloatPixels(in: HarbethIO(element: source, filter: base).renderTexture(profile: .exportQuality))
            for region in [(5, 7, 17, 11), (2, 3, 15, 13), (16, 12, 21, 17)] {
                let (x, y, w, h) = region
                let input = quantizationCrop(values, width: width, x: x, y: y, w: w, h: h)
                let tile = try makeRGBA16FloatTexture(width: w, height: h, pixels: input)
                let filter = QuantizationRegionFilter(base: base, origin: SIMD2<Float>(Float(x), Float(y)), logicalSize: SIMD2<Float>(Float(width), Float(height)))
                let expected = quantizationCrop(full.map(Float16.init), width: width, x: x, y: y, w: w, h: h).map(Float.init)
                let io = try HarbethIO(element: tile, filter: filter).renderTexture(profile: .exportQuality)
                let node = try ImageNode.texture(tile).applying(filter).makeFrame(profile: .exportQuality)
                XCTAssertEqual(try rgba16FloatPixels(in: io), expected, "区域输出必须使用全图坐标")
                XCTAssertEqual(try rgba16FloatPixels(in: node.texture), expected)
            }
        }
    }

    func testOutputQuantizationPatternsPreserveEveryAlphaPixel() throws {
        let width = 7, height = 5
        let values = quantizationFixture(width: width, height: height)
        let source = try makeRGBA16FloatTexture(width: width, height: height, pixels: values)
        for pattern in [ImageDitherPattern.none, .ordered2x2, .ordered4x4, .ordered8x8, .interleavedGradient] {
            let filter = C7OutputQuantization(bitDepth: 2, pattern: pattern, seed: 41)
            let output = try rgba16FloatPixels(in: HarbethIO(element: source, filter: filter).renderTexture(profile: .exportQuality))
            for index in stride(from: 3, to: values.count, by: 4) {
                XCTAssertEqual(output[index], Float(values[index]))
            }
        }
    }

    func testOutputQuantizationZeroStrengthIgnoresPatternSeedAndRegionOrigin() throws {
        let values = quantizationFixture(width: 7, height: 5)
        let source = try makeRGBA16FloatTexture(width: 7, height: 5, pixels: values)
        let expected = try rgba16FloatPixels(in: HarbethIO(element: source, filter: C7OutputQuantization(bitDepth: 4, pattern: .none)).renderTexture(profile: .exportQuality))
        for pattern in [ImageDitherPattern.ordered2x2, .ordered4x4, .ordered8x8, .interleavedGradient] {
            for seed: UInt32 in [0, 71] {
                let filter = QuantizationRegionFilter(base: C7OutputQuantization(bitDepth: 4, pattern: pattern, strength: 0, seed: seed), origin: SIMD2<Float>(13, 9), logicalSize: SIMD2<Float>(37, 29))
                XCTAssertEqual(try rgba16FloatPixels(in: HarbethIO(element: source, filter: filter).renderTexture(profile: .exportQuality)), expected)
            }
        }
    }

    func testOutputQuantizationRegionSeedReplayIsDeterministic() throws {
        let source = try makeRGBA16FloatTexture(width: 7, height: 5, pixels: quantizationFixture(width: 7, height: 5))
        for pattern in [ImageDitherPattern.ordered2x2, .ordered4x4, .ordered8x8, .interleavedGradient] {
            let filter = QuantizationRegionFilter(base: C7OutputQuantization(bitDepth: 3, pattern: pattern, seed: 71), origin: SIMD2<Float>(5, 7), logicalSize: SIMD2<Float>(37, 29))
            let first = try rgba16FloatPixels(in: HarbethIO(element: source, filter: filter).renderTexture(profile: .exportQuality))
            let second = try rgba16FloatPixels(in: HarbethIO(element: source, filter: filter).renderTexture(profile: .exportQuality))
            XCTAssertEqual(first, second)
        }
    }

    func testOutputQuantizationOrderedMatricesMatchIndependentThresholdOracle() throws {
        let matrices: [(ImageDitherPattern, Int, [Int])] = [
            (.ordered2x2, 2, [0, 2, 3, 1]),
            (.ordered4x4, 4, [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]),
            (.ordered8x8, 8, [
                0, 32, 8, 40, 2, 34, 10, 42,
                48, 16, 56, 24, 50, 18, 58, 26,
                12, 44, 4, 36, 14, 46, 6, 38,
                60, 28, 52, 20, 62, 30, 54, 22,
                3, 35, 11, 43, 1, 33, 9, 41,
                51, 19, 59, 27, 49, 17, 57, 25,
                15, 47, 7, 39, 13, 45, 5, 37,
                63, 31, 55, 23, 61, 29, 53, 21
            ])
        ]
        for (pattern, edge, ranks) in matrices {
            for step in 0..<ranks.count {
                let value = Float16(Float(step) + 0.5) / Float16(ranks.count)
                let pixels = (0..<ranks.count).flatMap { _ in [value, value, value, Float16(0.25)] }
                let source = try makeRGBA16FloatTexture(width: edge, height: edge, pixels: pixels)
                let output = try rgba16FloatPixels(in: HarbethIO(
                    element: source,
                    filter: C7OutputQuantization(bitDepth: 1, pattern: pattern)
                ).renderTexture(profile: .exportQuality))
                for (index, rank) in ranks.enumerated() {
                    let expected: Float = step + rank + 1 >= ranks.count ? 1 : 0
                    for channel in 0..<3 {
                        XCTAssertEqual(output[index * 4 + channel], expected, "矩阵阈值或朝向不一致")
                    }
                    XCTAssertEqual(output[index * 4 + 3], 0.25)
                }
            }
        }
    }

    func testOutputQuantizationPatternContractsRoundTripWithStableFactors() throws {
        let cases: [(ImageDitherPattern, Float)] = [
            (.none, 0), (.ordered4x4, 1), (.interleavedGradient, 2),
            (.ordered2x2, 3), (.ordered8x8, 4)
        ]
        for (pattern, factor) in cases {
            let contract = OutputQuantizationContract(bitDepth: 3, ditherPattern: pattern, strength: 0.75, seed: 71)
            let restored = try JSONDecoder().decode(OutputQuantizationContract.self, from: JSONEncoder().encode(contract))
            XCTAssertEqual(restored, contract)
            XCTAssertEqual(C7OutputQuantization(contract: restored).factors, [3, factor, 0.75, 71])
        }
    }

    private func quantizationFixture(width: Int, height: Int) -> [Float16] {
        (0..<(width * height)).flatMap { index -> [Float16] in
            let x = index % width, y = index / width
            return [Float16(Float(x % 13) / 12), Float16(Float(y % 9) / 8), Float16(0.5), Float16(Float((x + y) % 5) / 4)]
        }
    }

    private func quantizationCrop(_ pixels: [Float16], width: Int, x: Int, y: Int, w: Int, h: Int) -> [Float16] {
        (y..<(y + h)).flatMap { row in Array(pixels[(row * width + x) * 4..<(row * width + x + w) * 4]) }
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

    private func makeRGBA16FloatTexture(width: Int, height: Int = 1, pixels: [Float16]) throws -> MTLTexture {
        guard pixels.count == width * height * 4 else {
            throw HarbethError.filterParameterInvalid("RGBA16Float dimensions do not match the pixel count.")
        }
        let texture = try makeTexture(pixelFormat: .rgba16Float, width: width, height: height)
        pixels.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
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
        var values = Array(repeating: Float16.zero, count: texture.width * texture.height * 4)
        values.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0
            )
        }
        return values.map(Float.init)
    }
}

/// 区域绑定同时提供原始因子，避免显式绑定覆盖默认 factors。
private struct QuantizationRegionFilter: C7FilterProtocol {
    let base: C7OutputQuantization
    let origin: SIMD2<Float>
    let logicalSize: SIMD2<Float>

    var modifier: ModifierEnum { base.modifier }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    var kernelParameterBindings: [KernelParameterBinding] {
        base.factors.enumerated().map { index, value in
            KernelParameterBinding(name: "quantization.\(index)", index: index, stage: .compute, value: .float(value))
        } + [
            KernelParameterBinding(name: "regionContext", index: 30, stage: .compute,
                value: .floatArray([origin.x, origin.y, logicalSize.x, logicalSize.y, origin.x, origin.y, logicalSize.x, logicalSize.y]))
        ]
    }
}
