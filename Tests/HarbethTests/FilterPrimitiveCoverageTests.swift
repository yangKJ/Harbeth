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

    func testOutputQuantizationIsDeterministicWithoutDitherAndPreservesAlpha() throws {
        let source = try makeRGBA8Texture(width: 1, pixels: [100, 100, 100, 123])
        let output: MTLTexture = try HarbethIO(
            element: source,
            filter: C7OutputQuantization(bitDepth: 4, pattern: .none)
        ).output()

        XCTAssertEqual(try rgba8Pixels(in: output), [102, 102, 102, 123])
    }

    private func makeRGBA8Texture(width: Int, pixels: [UInt8]) throws -> MTLTexture {
        guard pixels.count == width * 4 else {
            throw HarbethError.filterParameterInvalid("RGBA8 dimensions do not match the pixel count.")
        }
        let texture = try makeTexture(pixelFormat: .rgba8Unorm, width: width)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, 1),
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

    private func makeTexture(pixelFormat: MTLPixelFormat, width: Int) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: 1,
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
        var values = Array(repeating: UInt8.zero, count: texture.width * 4)
        texture.getBytes(
            &values,
            bytesPerRow: texture.width * 4,
            from: MTLRegionMake2D(0, 0, texture.width, 1),
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
