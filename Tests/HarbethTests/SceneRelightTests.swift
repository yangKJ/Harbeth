import Metal
import XCTest
@testable import Harbeth

final class SceneRelightTests: XCTestCase {

    func testDescriptorRejectsMoreThanThreeLightsAndSanitizesNonFiniteParameters() throws {
        let invalidLight = SceneLightDescriptor(
            position: SIMD3<Float>(.nan, .infinity, -.infinity),
            direction: .zero,
            color: SIMD3<Float>(-.infinity, .nan, 20),
            intensity: .nan,
            radius: -.infinity,
            softness: .infinity,
            coneAngleDegrees: .nan,
            falloff: -.infinity
        )
        XCTAssertThrowsError(try SceneRelightDescriptor(
            lights: Array(repeating: invalidLight, count: 4)
        )) { error in
            guard let harbethError = error as? HarbethError,
                  case .sceneRelightTooManyLights(let maximum, let actual) = harbethError else {
                return XCTFail("Expected HarbethError.sceneRelightTooManyLights, got \(error)")
            }
            XCTAssertEqual(maximum, 3)
            XCTAssertEqual(actual, 4)
        }
        let descriptor = try SceneRelightDescriptor(
            lights: Array(repeating: invalidLight, count: 3),
            ambient: .nan,
            originalLight: .infinity,
            normalStrength: -.infinity,
            depthScale: .nan,
            highlightRolloff: .infinity,
            confidenceFloor: -.infinity
        )

        XCTAssertEqual(descriptor.lights.count, SceneRelightDescriptor.maximumLightCount)
        XCTAssertEqual(descriptor.ambient, 1)
        XCTAssertEqual(descriptor.originalLight, 1)
        XCTAssertEqual(descriptor.lights[0].position, SIMD3<Float>(0.5, 0.5, 1.5))
        XCTAssertEqual(descriptor.lights[0].direction, SIMD3<Float>(0, 0, -1))
        XCTAssertEqual(descriptor.lights[0].color, SIMD3<Float>(1, 1, 8))
        XCTAssertEqual(descriptor.lights[0].intensity, 0)
    }

    func testDescriptorCodableRoundTripKeepsValidationGate() throws {
        let light = SceneLightDescriptor(kind: .spot, intensity: 1.2)
        let descriptor = try SceneRelightDescriptor(lights: [light], ambient: 0.4)
        let encoded = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(SceneRelightDescriptor.self, from: encoded)
        XCTAssertEqual(decoded, descriptor)

        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
              let lights = object["lights"] as? [Any],
              let firstLight = lights.first else {
            XCTFail("场景布光描述必须保持稳定的 Codable 结构。")
            return
        }
        object["lights"] = Array(repeating: firstLight, count: 4)
        let invalid = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(SceneRelightDescriptor.self, from: invalid))
    }

    func testDirectBindingKeepsStableDepthAndConfidenceTextureSlots() throws {
        let depth = try makeScalarTexture(values: [0.5])
        let confidence = try makeScalarTexture(values: [0.75])
        let withoutConfidence = C7SceneRelight(
            descriptor: .identity,
            depthTexture: depth
        )
        let withConfidence = C7SceneRelight(
            descriptor: .identity,
            depthTexture: depth,
            confidenceTexture: confidence
        )

        XCTAssertEqual(withoutConfidence.otherInputTextures.count, 2)
        XCTAssertTrue(withoutConfidence.otherInputTextures[0] === depth)
        XCTAssertTrue(withoutConfidence.otherInputTextures[1] === depth)
        XCTAssertFalse(withoutConfidence.expectsConfidencePlane)
        XCTAssertFalse(withoutConfidence.requiresDeferredDepthBinding)
        XCTAssertEqual(withConfidence.otherInputTextures.count, 2)
        XCTAssertTrue(withConfidence.otherInputTextures[0] === depth)
        XCTAssertTrue(withConfidence.otherInputTextures[1] === confidence)
        XCTAssertTrue(withConfidence.expectsConfidencePlane)
        XCTAssertEqual(packedParameters(of: withoutConfidence)[8], 0)
        XCTAssertEqual(packedParameters(of: withConfidence)[8], 1)
        XCTAssertEqual(packedParameters(of: withConfidence).count, C7SceneRelight.parameterCount)
    }

    func testDeferredBindingCannotMasqueradeAsCompleteDirectFilter() throws {
        let depth = try makeScalarTexture(values: [0.5])
        let direct = C7SceneRelight(descriptor: .identity, depthTexture: depth)
        let deferred = C7SceneRelight.deferred(.identity, hasConfidencePlane: false)

        XCTAssertFalse(direct.requiresDeferredDepthBinding)
        XCTAssertTrue(deferred.requiresDeferredDepthBinding)
        XCTAssertTrue(deferred.otherInputTextures.isEmpty)
        XCTAssertEqual(C7SceneRelight.requiredDeferredAuxiliaryTextureCount, 2)
        XCTAssertTrue(deferred.kernelResourceIdentity?.contains("binding=deferred") == true)
        XCTAssertNotEqual(direct.kernelResourceIdentity, deferred.kernelResourceIdentity)
        XCTAssertEqual(direct.makeKernelExecutionPlan(inputSize: C7Size(width: 1, height: 1)).inputTextureCount, 3)
        XCTAssertEqual(deferred.makeKernelExecutionPlan(inputSize: C7Size(width: 1, height: 1)).inputTextureCount, 1)
    }

    func testPixelContractDeclaresLinearHDRAlphaAndRegionalRequirements() throws {
        let depth = try makeScalarTexture(values: [0.5])
        let filter = C7SceneRelight(descriptor: .identity, depthTexture: depth)
        let contract = filter.kernelPixelContract

        XCTAssertEqual(contract.inputColorSpace.transferFunction, .linear)
        XCTAssertEqual(contract.workingColorSpace.transferFunction, .linear)
        XCTAssertEqual(contract.outputColorSpace.transferFunction, .linear)
        XCTAssertEqual(contract.outputAlpha, .preserveInput)
        XCTAssertEqual(contract.dynamicRangeBehavior, .preservesExtendedRange)
        XCTAssertEqual(contract.samplingFootprint, .neighborhood(radius: 1))
        XCTAssertEqual(contract.coordinateDependency, .fullImage)
        XCTAssertEqual(contract.globalDependency, .none)
        XCTAssertEqual(filter.memoryAccessPattern, .multiTexture)
        XCTAssertTrue(contract.canAutoTile)
    }

    func testIdentityLightingPreservesColorAndAlpha() throws {
        let source = try makeRGBA8Texture(pixels: [40, 80, 120, 128])
        let depth = try makeScalarTexture(values: [0.5])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SceneRelight(descriptor: .identity, depthTexture: depth)
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: output), [40, 80, 120, 128])
    }

    func testDirectionalLightAppliesLinearColorWithoutChangingAlpha() throws {
        let source = try makeRGBA8Texture(pixels: [64, 64, 64, 128])
        let depth = try makeScalarTexture(values: [0.5])
        let descriptor = try SceneRelightDescriptor(
            lights: [
                SceneLightDescriptor(
                    kind: .directional,
                    direction: SIMD3<Float>(0, 0, -1),
                    color: SIMD3<Float>(2, 1, 0.5),
                    intensity: 1
                )
            ],
            ambient: 0,
            originalLight: 0,
            highlightRolloff: 0
        )
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SceneRelight(descriptor: descriptor, depthTexture: depth)
        ).output()

        let pixel = try rgba8Pixel(in: output)
        XCTAssertEqual(pixel[0], 128, accuracy: 1)
        XCTAssertEqual(pixel[1], 64, accuracy: 1)
        XCTAssertEqual(pixel[2], 32, accuracy: 1)
        XCTAssertEqual(pixel[3], 128)
    }

    func testZeroConfidenceProtectsOriginalAndAbsentConfidenceUsesUnweightedRelight() throws {
        let source = try makeRGBA8Texture(pixels: [50, 100, 150, 200])
        let depth = try makeScalarTexture(values: [0.5])
        let zeroConfidence = try makeScalarTexture(values: [0])
        let descriptor = try SceneRelightDescriptor(
            ambient: 0,
            originalLight: 0,
            highlightRolloff: 0,
            confidenceFloor: 0
        )
        let protected: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SceneRelight(
                descriptor: descriptor,
                depthTexture: depth,
                confidenceTexture: zeroConfidence
            )
        ).output()
        let withoutConfidence: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SceneRelight(descriptor: descriptor, depthTexture: depth)
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: protected), [50, 100, 150, 200])
        XCTAssertEqual(try rgba8Pixel(in: withoutConfidence), [0, 0, 0, 200])
    }

    func testNonFiniteDepthFallsBackToOriginalPixel() throws {
        let source = try makeRGBA8Texture(pixels: [30, 60, 90, 120])
        let depth = try makeScalarTexture(values: [.nan])
        let descriptor = try SceneRelightDescriptor(ambient: 0, originalLight: 0, highlightRolloff: 0)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SceneRelight(descriptor: descriptor, depthTexture: depth)
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: output), [30, 60, 90, 120])
    }

    func testLowResolutionDepthPlaneUsesFullCanvasUVForEachTile() throws {
        let source = try makeRGBA8Texture(pixels: [30, 60, 90, 120])
        let depth = try makeScalarTexture(width: 3, height: 1, values: [.nan, 0.5, 0.5])
        let descriptor = try SceneRelightDescriptor(ambient: 0, originalLight: 0, highlightRolloff: 0)
        let base = C7SceneRelight(descriptor: descriptor, depthTexture: depth)
        let leftTile: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(base: base, originX: 0, logicalWidth: 6)
        ).output()
        let rightTile: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(base: base, originX: 5, logicalWidth: 6)
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: leftTile), [30, 60, 90, 120])
        XCTAssertEqual(try rgba8Pixel(in: rightTile), [0, 0, 0, 120])
    }

    func testLowResolutionDepthPlaneUsesBilinearInterpolationInFullCanvasUV() throws {
        let source = try makeRGBA8Texture(pixels: [64, 64, 64, 255])
        let rampDepth = try makeScalarTexture(width: 2, height: 1, values: [0, 1])
        let referenceDepth = try makeScalarTexture(width: 2, height: 1, values: [0.25, 0.25])
        let descriptor = try SceneRelightDescriptor(
            lights: [
                SceneLightDescriptor(
                    kind: .point,
                    position: SIMD3<Float>(0.375, 0.5, 1.5),
                    intensity: 1,
                    radius: 4,
                    softness: 0,
                    falloff: 1
                )
            ],
            ambient: 0,
            originalLight: 0,
            normalStrength: 0,
            depthScale: 4,
            highlightRolloff: 0
        )
        let rampOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(descriptor: descriptor, depthTexture: rampDepth),
                originX: 1,
                logicalWidth: 4
            )
        ).output()
        let referenceOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(descriptor: descriptor, depthTexture: referenceDepth),
                originX: 1,
                logicalWidth: 4
            )
        ).output()

        let rampPixel = try rgba8Pixel(in: rampOutput)
        let referencePixel = try rgba8Pixel(in: referenceOutput)
        for channel in 0..<4 {
            XCTAssertEqual(rampPixel[channel], referencePixel[channel], accuracy: 1)
        }
        XCTAssertLessThan(rampPixel[0], 64)
    }

    func testPartiallyInvalidDepthNeighborhoodDoesNotHardFallbackToOriginal() throws {
        let source = try makeRGBA8Texture(pixels: [30, 60, 90, 120])
        let depth = try makeScalarTexture(width: 3, height: 1, values: [.nan, 0.5, 0.5])
        let descriptor = try SceneRelightDescriptor(ambient: 0, originalLight: 0, highlightRolloff: 0)
        let base = C7SceneRelight(descriptor: descriptor, depthTexture: depth)
        let fullyInvalid: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(base: base, originX: 0, logicalWidth: 6)
        ).output()
        let partiallyValid: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(base: base, originX: 2, logicalWidth: 6)
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: fullyInvalid), [30, 60, 90, 120])
        XCTAssertEqual(try rgba8Pixel(in: partiallyValid), [0, 0, 0, 120])
    }

    func testDepthNormalUsesSceneSpaceSlopeAcrossCanvasAspectRatios() throws {
        let source = try makeRGBA8Texture(pixels: [64, 64, 64, 200])
        let sceneSlope: Float = 0.2
        let wideAspect: Float = 2
        let tallAspect: Float = 0.5
        let wideDepth = try makeScalarTexture(
            width: 8,
            height: 1,
            values: (0..<8).map { index in
                let canvasU = (Float(index) + 0.5) / 8
                return 0.5 + sceneSlope * wideAspect * (canvasU - 0.5)
            }
        )
        let tallDepth = try makeScalarTexture(
            width: 4,
            height: 1,
            values: (0..<4).map { index in
                let canvasU = (Float(index) + 0.5) / 4
                return 0.5 + sceneSlope * tallAspect * (canvasU - 0.5)
            }
        )
        let descriptor = try SceneRelightDescriptor(
            lights: [
                SceneLightDescriptor(
                    kind: .directional,
                    direction: SIMD3<Float>(1, 0, -0.2),
                    intensity: 1
                )
            ],
            ambient: 0,
            originalLight: 0,
            normalStrength: 1,
            depthScale: 4,
            highlightRolloff: 0
        )
        let wideOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(descriptor: descriptor, depthTexture: wideDepth),
                originX: 3,
                originY: 1,
                logicalWidth: 8,
                logicalHeight: 4
            )
        ).output()
        let tallOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(descriptor: descriptor, depthTexture: tallDepth),
                originX: 1,
                originY: 3,
                logicalWidth: 4,
                logicalHeight: 8
            )
        ).output()

        let widePixel = try rgba8Pixel(in: wideOutput)
        let tallPixel = try rgba8Pixel(in: tallOutput)
        for channel in 0..<4 {
            XCTAssertEqual(widePixel[channel], tallPixel[channel], accuracy: 1)
        }
        XCTAssertLessThan(widePixel[0], 64)
    }

    func testLowResolutionConfidencePlaneUsesTheSameFullCanvasUV() throws {
        let source = try makeRGBA8Texture(pixels: [30, 60, 90, 120])
        let depth = try makeScalarTexture(width: 3, height: 1, values: [0.5, 0.5, 0.5])
        let confidence = try makeScalarTexture(width: 3, height: 1, values: [0, 0, 1])
        let descriptor = try SceneRelightDescriptor(ambient: 0, originalLight: 0, highlightRolloff: 0)
        let base = C7SceneRelight(
            descriptor: descriptor,
            depthTexture: depth,
            confidenceTexture: confidence
        )
        let leftTile: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(base: base, originX: 0, logicalWidth: 6)
        ).output()
        let rightTile: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(base: base, originX: 5, logicalWidth: 6)
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: leftTile), [30, 60, 90, 120])
        XCTAssertEqual(try rgba8Pixel(in: rightTile), [0, 0, 0, 120])
    }

    func testLowResolutionConfidencePlaneUsesBilinearInterpolationInFullCanvasUV() throws {
        let source = try makeRGBA8Texture(pixels: [64, 96, 128, 200])
        let depth = try makeScalarTexture(values: [0.5])
        let rampConfidence = try makeScalarTexture(width: 2, height: 1, values: [0, 1])
        let referenceConfidence = try makeScalarTexture(width: 2, height: 1, values: [0.25, 0.25])
        let descriptor = try SceneRelightDescriptor(
            ambient: 0,
            originalLight: 0,
            highlightRolloff: 0,
            confidenceFloor: 0
        )
        let rampOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(
                    descriptor: descriptor,
                    depthTexture: depth,
                    confidenceTexture: rampConfidence
                ),
                originX: 1,
                logicalWidth: 4
            )
        ).output()
        let referenceOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(
                    descriptor: descriptor,
                    depthTexture: depth,
                    confidenceTexture: referenceConfidence
                ),
                originX: 1,
                logicalWidth: 4
            )
        ).output()

        let rampPixel = try rgba8Pixel(in: rampOutput)
        let referencePixel = try rgba8Pixel(in: referenceOutput)
        for channel in 0..<4 {
            XCTAssertEqual(rampPixel[channel], referencePixel[channel], accuracy: 1)
        }
        XCTAssertLessThan(rampPixel[0], 64)
    }

    func testConfidenceSamplingIgnoresInvalidContributorsAndFullyInvalidFallsBack() throws {
        let source = try makeRGBA8Texture(pixels: [40, 80, 120, 200])
        let depth = try makeScalarTexture(values: [0.5])
        let partiallyValidConfidence = try makeScalarTexture(width: 2, height: 1, values: [.nan, 1])
        let fullyInvalidConfidence = try makeScalarTexture(width: 2, height: 1, values: [.nan, .infinity])
        let descriptor = try SceneRelightDescriptor(
            ambient: 0,
            originalLight: 0,
            highlightRolloff: 0,
            confidenceFloor: 0
        )
        let partiallyValid: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(
                    descriptor: descriptor,
                    depthTexture: depth,
                    confidenceTexture: partiallyValidConfidence
                ),
                originX: 1,
                logicalWidth: 4
            )
        ).output()
        let fullyInvalid: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(
                    descriptor: descriptor,
                    depthTexture: depth,
                    confidenceTexture: fullyInvalidConfidence
                ),
                originX: 1,
                logicalWidth: 4
            )
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: partiallyValid), [0, 0, 0, 200])
        XCTAssertEqual(try rgba8Pixel(in: fullyInvalid), [40, 80, 120, 200])
    }

    func testAnyPositiveValidAuxiliaryWeightPreventsFallback() throws {
        let source = try makeRGBA8Texture(pixels: [40, 80, 120, 200])
        let depth = try makeScalarTexture(values: [0.5])
        let confidence = try makeScalarTexture(width: 2, height: 1, values: [.nan, 1])
        let descriptor = try SceneRelightDescriptor(
            ambient: 0,
            originalLight: 0,
            highlightRolloff: 0,
            confidenceFloor: 0
        )
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: SceneRelightMappingFilter(
                base: C7SceneRelight(
                    descriptor: descriptor,
                    depthTexture: depth,
                    confidenceTexture: confidence
                ),
                originX: 1_000_000,
                logicalWidth: 4_000_000
            )
        ).output()

        XCTAssertEqual(try rgba8Pixel(in: output), [0, 0, 0, 200])
    }

    func testHDRValuesRemainExtendedAndAlphaIsPreserved() throws {
        let source = try makeRGBA16FloatTexture(pixel: [2, 0.5, -0.25, 0.4])
        let depth = try makeScalarTexture(values: [0.5])
        let descriptor = try SceneRelightDescriptor(ambient: 2, originalLight: 0, highlightRolloff: 0)
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7SceneRelight(descriptor: descriptor, depthTexture: depth)
        ).output()
        let pixel = try rgba16FloatPixel(in: output)

        XCTAssertGreaterThan(pixel[0], 1)
        XCTAssertEqual(pixel[0], 4, accuracy: 0.01)
        XCTAssertEqual(pixel[1], 1, accuracy: 0.01)
        XCTAssertEqual(pixel[2], -0.5, accuracy: 0.01)
        XCTAssertEqual(pixel[3], 0.4, accuracy: 0.01)
    }

    func testRGBA16FloatSceneRelightDiagnosticsPreserveTexturePixelFormat() throws {
        let source = try makeRGBA16FloatTexture(pixel: [2, 0.5, -0.25, 0.4])
        let depth = try makeScalarTexture(values: [0.5])
        let diagnostics = try ImageNode
            .texture(source)
            .applying(C7SceneRelight(descriptor: .identity, depthTexture: depth))
            .makeDiagnostics()

        XCTAssertEqual(diagnostics.inputPixelFormat, .rgba16Float)
        XCTAssertEqual(diagnostics.outputPixelFormat, .rgba16Float)
        XCTAssertTrue(diagnostics.inputPixelFormat.isHighPrecision)
        XCTAssertTrue(diagnostics.outputPixelFormat.isHighPrecision)
    }

    func testSRGBTransferRoundTripKeepsExtendedHeadroomForRelighting() throws {
        let source = try makeRGBA16FloatTexture(pixel: [2, 1.25, -0.1, 0.4])
        let linear: MTLTexture = try HarbethIO(
            element: source,
            filter: C7RGBTransferConversion(mode: .sRGBToLinear)
        ).output()
        let encoded: MTLTexture = try HarbethIO(
            element: linear,
            filter: C7RGBTransferConversion(mode: .linearToSRGB)
        ).output()
        let pixel = try rgba16FloatPixel(in: encoded)

        XCTAssertEqual(pixel[0], 2, accuracy: 0.02)
        XCTAssertEqual(pixel[1], 1.25, accuracy: 0.02)
        XCTAssertEqual(pixel[2], -0.1, accuracy: 0.01)
        XCTAssertEqual(pixel[3], 0.4, accuracy: 0.01)
    }

    func testAlphaRoundTripKeepsStraightExtendedColorForRelighting() throws {
        let source = try makeRGBA16FloatTexture(pixel: [1, 0.25, -0.1, 0.5])
        let straight: MTLTexture = try HarbethIO(
            element: source,
            filter: C7UnpremultiplyAlpha()
        ).output()
        let straightPixel = try rgba16FloatPixel(in: straight)
        XCTAssertEqual(straightPixel[0], 2, accuracy: 0.01)
        XCTAssertEqual(straightPixel[1], 0.5, accuracy: 0.01)
        XCTAssertEqual(straightPixel[2], -0.2, accuracy: 0.01)

        let premultiplied: MTLTexture = try HarbethIO(
            element: straight,
            filter: C7PremultiplyAlpha()
        ).output()
        let roundTrip = try rgba16FloatPixel(in: premultiplied)
        XCTAssertEqual(roundTrip[0], 1, accuracy: 0.01)
        XCTAssertEqual(roundTrip[1], 0.25, accuracy: 0.01)
        XCTAssertEqual(roundTrip[2], -0.1, accuracy: 0.01)
        XCTAssertEqual(roundTrip[3], 0.5, accuracy: 0.01)
    }

    private func packedParameters(of filter: C7SceneRelight) -> [Float] {
        guard case .floatArray(let values) = filter.kernelParameterBindings.first?.value else {
            XCTFail("场景布光必须使用固定 float-array ABI。")
            return []
        }
        return values
    }

    private func makeRGBA8Texture(pixels: [UInt8]) throws -> MTLTexture {
        guard pixels.count == 4 else { throw HarbethError.filterParameterInvalid("Expected one RGBA8 pixel.") }
        let texture = try makeTexture(pixelFormat: .rgba8Unorm)
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: 4
        )
        return texture
    }

    private func makeRGBA16FloatTexture(pixel: [Float16]) throws -> MTLTexture {
        guard pixel.count == 4 else { throw HarbethError.filterParameterInvalid("Expected one RGBA16Float pixel.") }
        let texture = try makeTexture(pixelFormat: .rgba16Float)
        pixel.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: 8
            )
        }
        return texture
    }

    private func makeScalarTexture(width: Int = 1, height: Int = 1, values: [Float]) throws -> MTLTexture {
        guard values.count == width * height else {
            throw HarbethError.filterParameterInvalid("Scalar plane dimensions do not match its value count.")
        }
        let texture = try makeTexture(pixelFormat: .r32Float, width: width, height: height)
        values.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * 4
            )
        }
        return texture
    }

    private func makeTexture(pixelFormat: MTLPixelFormat, width: Int = 1, height: Int = 1) throws -> MTLTexture {
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

    private func rgba8Pixel(in texture: MTLTexture) throws -> [UInt8] {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            throw HarbethError.texture2Image
        }
        return Array(bytes.prefix(4))
    }

    private func rgba16FloatPixel(in texture: MTLTexture) throws -> [Float] {
        guard texture.pixelFormat == .rgba16Float else {
            throw HarbethError.filterParameterInvalid("Expected an RGBA16Float output.")
        }
        var values = Array(repeating: Float16.zero, count: 4)
        values.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: 8,
                from: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0
            )
        }
        return values.map(Float.init)
    }
}

private struct SceneRelightMappingFilter: C7FilterProtocol {
    let base: C7SceneRelight
    let originX: Float
    let originY: Float
    let logicalWidth: Float
    let logicalHeight: Float

    init(
        base: C7SceneRelight,
        originX: Float,
        originY: Float = 0,
        logicalWidth: Float,
        logicalHeight: Float = 1
    ) {
        self.base = base
        self.originX = originX
        self.originY = originY
        self.logicalWidth = logicalWidth
        self.logicalHeight = logicalHeight
    }

    var modifier: ModifierEnum { base.modifier }
    var otherInputTextures: C7InputTextures { base.otherInputTextures }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    var kernelResourceIdentity: String? { base.kernelResourceIdentity }

    var kernelParameterBindings: [KernelParameterBinding] {
        base.kernelParameterBindings + [
            KernelParameterBinding(
                name: "mappingContext",
                index: 30,
                stage: .compute,
                value: .floatArray([
                    originX, originY, logicalWidth, logicalHeight,
                    originX, originY, logicalWidth, logicalHeight
                ])
            )
        ]
    }
}
