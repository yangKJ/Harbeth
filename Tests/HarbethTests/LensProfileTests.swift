import XCTest
import Metal
@testable import Harbeth

final class LensProfileTests: XCTestCase {

    func testLensVignetteCorrectionIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 100, green: 100, blue: 100, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7LensVignetteCorrection()
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 100, accuracy: 2)
        XCTAssertEqual(pixel.green, 100, accuracy: 2)
        XCTAssertEqual(pixel.blue, 100, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testLensVignetteCorrectionKeepsInputSize() {
        let filter = C7LensVignetteCorrection(amount: 1.2, start: 0.3, end: 0.95)
        XCTAssertEqual(filter.resize(input: C7Size(width: 320, height: 240)), C7Size(width: 320, height: 240))
    }

    func testLensProfileBuildsAllOpticsFilters() {
        let profile = LensProfile(
            make: "Demo",
            model: "UltraWide",
            profileName: "Default",
            distortionCorrection: .init(distortion: -0.2, cubicDistortion: 0.04, scale: 1.02),
            chromaticAberrationCorrection: .init(redCyanShift: -0.01, blueYellowShift: 0.015),
            vignetteCorrection: .init(amount: 1.1, start: 0.3, end: 0.95),
            diffractionCorrection: .init(amount: 0.6, radius: 1.5, edgeThreshold: 0.09)
        )

        XCTAssertNotNil(profile.makeDistortionFilter())
        XCTAssertNotNil(profile.makeChromaticAberrationFilter())
        XCTAssertNotNil(profile.makeVignetteFilter())
        XCTAssertNotNil(profile.makeDiffractionFilter())
        XCTAssertEqual(profile.makeCorrectionFilters().count, 4)
    }

    func testDefringeIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 180, green: 20, blue: 180, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7DefringeCorrection()
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 180, accuracy: 2)
        XCTAssertEqual(pixel.green, 20, accuracy: 2)
        XCTAssertEqual(pixel.blue, 180, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testDefringeSuppressesPurpleFringeOnHighContrastEdge() throws {
        let input = try makeThreePixelTexture(
            pixels: [
                (255, 255, 255, 255),
                (190, 40, 190, 255),
                (0, 0, 0, 255)
            ]
        )

        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7DefringeCorrection(purpleAmount: 1.0, edgeThreshold: 0.01, saturationThreshold: 0.01)
        ).output()

        let pixels = try readPixels(in: output, count: 3)
        XCTAssertLessThan(pixels[1].red, 190)
        XCTAssertLessThan(pixels[1].blue, 190)
        XCTAssertEqual(pixels[1].alpha, 255)
    }

    func testSharpnessFalloffIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 90, green: 120, blue: 180, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7SharpnessFalloffCorrection()
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 90, accuracy: 2)
        XCTAssertEqual(pixel.green, 120, accuracy: 2)
        XCTAssertEqual(pixel.blue, 180, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testDiffractionIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 120, green: 140, blue: 160, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7DiffractionCorrection()
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 120, accuracy: 2)
        XCTAssertEqual(pixel.green, 140, accuracy: 2)
        XCTAssertEqual(pixel.blue, 160, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testOpticsSettingsBuildFiltersInStableOrder() {
        let profile = LensProfile(
            make: "Demo",
            model: "UltraWide",
            profileName: "Default",
            distortionCorrection: .init(distortion: -0.2, cubicDistortion: 0.04, scale: 1.02),
            chromaticAberrationCorrection: .init(redCyanShift: -0.01, blueYellowShift: 0.015),
            vignetteCorrection: .init(amount: 1.1, start: 0.3, end: 0.95),
            diffractionCorrection: .init(amount: 0.6, radius: 1.5, edgeThreshold: 0.09)
        )
        let settings = OpticsSettings(
            profile: profile,
            defringe: .init(purpleAmount: 0.8),
            sharpnessFalloff: .init(amount: 0.6)
        )

        let filters = settings.makeFilters()
        XCTAssertEqual(filters.count, 6)
        XCTAssertTrue(filters[0] is C7LensDistortionCorrection)
        XCTAssertTrue(filters[1] is C7ChromaticAberrationCorrection)
        XCTAssertTrue(filters[2] is C7LensVignetteCorrection)
        XCTAssertTrue(filters[3] is C7DiffractionCorrection)
        XCTAssertTrue(filters[4] is C7DefringeCorrection)
        XCTAssertTrue(filters[5] is C7SharpnessFalloffCorrection)
    }

    func testOpticsSettingsCanScaleProfileCorrections() {
        let profile = LensProfile(
            make: "Demo",
            model: "UltraWide",
            profileName: "Default",
            distortionCorrection: .init(distortion: -0.2, cubicDistortion: 0.04, scale: 1.02),
            chromaticAberrationCorrection: .init(redCyanShift: -0.01, blueYellowShift: 0.015),
            vignetteCorrection: .init(amount: 1.1, start: 0.3, end: 0.95),
            diffractionCorrection: .init(amount: 0.6, radius: 1.5, edgeThreshold: 0.09)
        )
        let settings = OpticsSettings(
            profile: profile,
            profileStrength: .init(distortion: 0.5, chromaticAberration: 0.25, vignette: 0.75, diffraction: 0.5)
        )

        let filters = settings.makeFilters()
        let distortion = filters[0] as? C7LensDistortionCorrection
        let chromatic = filters[1] as? C7ChromaticAberrationCorrection
        let vignette = filters[2] as? C7LensVignetteCorrection
        let diffraction = filters[3] as? C7DiffractionCorrection

        XCTAssertNotNil(distortion)
        XCTAssertNotNil(chromatic)
        XCTAssertNotNil(vignette)
        XCTAssertNotNil(diffraction)

        XCTAssertEqual(distortion!.distortion, Float(-0.1), accuracy: Float(0.0001))
        XCTAssertEqual(distortion!.cubicDistortion, Float(0.02), accuracy: Float(0.0001))
        XCTAssertEqual(distortion!.scale, Float(1.01), accuracy: Float(0.0001))
        XCTAssertEqual(chromatic!.redCyanShift, Float(-0.0025), accuracy: Float(0.0001))
        XCTAssertEqual(chromatic!.blueYellowShift, Float(0.00375), accuracy: Float(0.0001))
        XCTAssertEqual(vignette!.amount, Float(0.825), accuracy: Float(0.0001))
        XCTAssertEqual(diffraction!.amount, Float(0.3), accuracy: Float(0.0001))
    }

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create lens vignette fixture texture.")
            throw HarbethError.textureLoader
        }

        let bytes: [UInt8] = [red, green, blue, alpha]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 4
        )
        return texture
    }

    private func makeThreePixelTexture(pixels: [(UInt8, UInt8, UInt8, UInt8)]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: pixels.count,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create defringe fixture texture.")
            throw HarbethError.textureLoader
        }

        let bytes = pixels.flatMap { [$0.0, $0.1, $0.2, $0.3] }
        texture.replace(
            region: MTLRegionMake2D(0, 0, pixels.count, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: pixels.count * 4
        )
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }

    private func readPixels(in texture: MTLTexture, count: Int) throws -> [(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)] {
        guard let bytes = texture.c7.bytes(), bytes.count >= count * 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }

        var result: [(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)] = []
        for index in 0..<count {
            let offset = index * 4
            result.append((bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]))
        }
        return result
    }
}
