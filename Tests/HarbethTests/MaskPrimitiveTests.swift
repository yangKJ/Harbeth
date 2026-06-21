import XCTest
import Metal
@testable import Harbeth

final class MaskPrimitiveTests: XCTestCase {

    func testMaskBlendUsesMaskOpacity() throws {
        let base = try makeTexture(pixel: [255, 0, 0, 255])
        let effect = try makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 0)
        XCTAssertEqual(pixel.blue, 255)
    }

    func testMaskBlendCanInvertMask() throws {
        let base = try makeTexture(pixel: [255, 0, 0, 255])
        let effect = try makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, invert: true, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 255)
        XCTAssertEqual(pixel.blue, 0)
    }

    func testMaskBlendRespectsTransparentAndOpaqueOpacity() throws {
        let base = try makeTexture(pixel: [255, 0, 0, 255])
        let effect = try makeTexture(pixel: [0, 255, 0, 255])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])

        let transparentOutput: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(
                effectTexture: effect,
                mask: MaskDescriptor(texture: maskTexture, opacity: 0)
            )
        ).output()
        let opaqueOutput: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(
                effectTexture: effect,
                mask: MaskDescriptor(texture: maskTexture, opacity: 1)
            )
        ).output()

        XCTAssertEqual(try firstPixel(in: transparentOutput).red, 255)
        XCTAssertEqual(try firstPixel(in: opaqueOutput).green, 255)
    }

    func testMaskBlendSelectsRequestedColorComponent() throws {
        let base = try makeTexture(pixel: [255, 0, 0, 255])
        let effect = try makeTexture(pixel: [0, 255, 0, 255])
        let redMask = try makeTexture(pixel: [255, 0, 0, 0])
        let greenMask = try makeTexture(pixel: [0, 255, 0, 0])

        let redOutput: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(
                effectTexture: effect,
                mask: MaskDescriptor(texture: redMask, component: .red, opacity: 1)
            )
        ).output()
        let greenOutput: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(
                effectTexture: effect,
                mask: MaskDescriptor(texture: greenMask, component: .red, opacity: 1)
            )
        ).output()

        XCTAssertEqual(try firstPixel(in: redOutput).green, 255)
        XCTAssertEqual(try firstPixel(in: greenOutput).red, 255)
    }

    func testMaskBlendAddModeAddsEffectThroughOpaqueMask() throws {
        let base = try makeTexture(pixel: [100, 50, 25, 255])
        let effect = try makeTexture(pixel: [80, 100, 120, 128])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, blendMode: .add, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 180, accuracy: 2)
        XCTAssertEqual(pixel.green, 150, accuracy: 2)
        XCTAssertEqual(pixel.blue, 145, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testMaskBlendMultiplyModeMultipliesEffectThroughOpaqueMask() throws {
        let base = try makeTexture(pixel: [100, 50, 25, 255])
        let effect = try makeTexture(pixel: [80, 100, 120, 128])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, blendMode: .multiply, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 31, accuracy: 2)
        XCTAssertEqual(pixel.green, 20, accuracy: 2)
        XCTAssertEqual(pixel.blue, 12, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 128, accuracy: 2)
    }

    func testMaskBlendSubtractModeSubtractsEffectThroughOpaqueMask() throws {
        let base = try makeTexture(pixel: [120, 140, 160, 255])
        let effect = try makeTexture(pixel: [80, 40, 20, 64])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, blendMode: .subtract, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 40, accuracy: 2)
        XCTAssertEqual(pixel.green, 100, accuracy: 2)
        XCTAssertEqual(pixel.blue, 140, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 191, accuracy: 2)
    }

    func testMaskCoverageBlendMultiplyBuildsIntersectionCoverageTexture() throws {
        let baseCoverage = try makeTexture(pixel: [0, 0, 0, 192])
        let overlayMask = try makeTexture(pixel: [64, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: overlayMask, component: .red, blendMode: .multiply, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: baseCoverage,
            filter: C7MaskCoverageBlend(mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 48, accuracy: 3)
        XCTAssertEqual(pixel.green, 48, accuracy: 3)
        XCTAssertEqual(pixel.blue, 48, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2)
    }

    func testMaskCoverageExtractNormalizesDescriptorIntoCoverageTexture() throws {
        let maskTexture = try makeTexture(pixel: [128, 64, 32, 255])
        let output: MTLTexture = try HarbethIO(
            element: maskTexture,
            filter: C7MaskCoverageExtract(
                mask: MaskDescriptor(
                    texture: maskTexture,
                    component: .red,
                    featherPolicy: .none,
                    opacity: 0.5
                )
            )
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 64, accuracy: 3)
        XCTAssertEqual(pixel.green, 64, accuracy: 3)
        XCTAssertEqual(pixel.blue, 64, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2)
    }

    func testMaskCoverageBlendOutputCanDriveSubtractiveLocalEffect() throws {
        let baseImage = try makeTexture(pixel: [255, 0, 0, 255])
        let effectImage = try makeTexture(pixel: [0, 0, 255, 255])
        let baseCoverage = try makeTexture(pixel: [0, 0, 0, 255])
        let subtractMask = try makeTexture(pixel: [128, 0, 0, 255])

        let combinedMask: MTLTexture = try HarbethIO(
            element: baseCoverage,
            filter: C7MaskCoverageBlend(
                mask: MaskDescriptor(texture: subtractMask, component: .red, blendMode: .subtract, opacity: 1)
            )
        ).output()

        let output: MTLTexture = try HarbethIO(
            element: baseImage,
            filter: C7MaskRegionBlend(
                effectTexture: effectImage,
                mask: MaskDescriptor(texture: combinedMask, component: .red, opacity: 1)
            )
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 127, accuracy: 3)
        XCTAssertEqual(pixel.green, 0, accuracy: 2)
        XCTAssertEqual(pixel.blue, 128, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2)
    }

    func testMaskCompositeRecipeBuildsReusableCoverageTexture() throws {
        let baseMask = try makeTexture(pixel: [0, 0, 0, 192])
        let subtractMask = try makeTexture(pixel: [128, 0, 0, 255])
        let recipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseMask),
            masks: [
                MaskDescriptor(texture: subtractMask, component: .red, blendMode: .subtract, opacity: 1)
            ]
        )

        let coverage = try recipe.makeTexture()
        let coveragePixel = try firstPixel(in: coverage)
        let descriptor = try recipe.makeMaskDescriptor()
        let baseImage = try makeTexture(pixel: [255, 255, 255, 255])
        let effectImage = try makeTexture(pixel: [0, 0, 0, 255])
        let output: MTLTexture = try HarbethIO(
            element: baseImage,
            filter: C7MaskRegionBlend(effectTexture: effectImage, mask: descriptor)
        ).output()
        let pixel = try firstPixel(in: output)

        XCTAssertEqual(recipe.maskCount, 2)
        XCTAssertTrue(recipe.fingerprint.contains("profile=stablePreview"))
        XCTAssertTrue(recipe.fingerprint.contains("blend=4"))
        XCTAssertEqual(coveragePixel.red, 95, accuracy: 4)
        XCTAssertEqual(coveragePixel.green, 95, accuracy: 4)
        XCTAssertEqual(coveragePixel.blue, 95, accuracy: 4)
        XCTAssertEqual(pixel.red, 160, accuracy: 4)
        XCTAssertEqual(pixel.green, 160, accuracy: 4)
        XCTAssertEqual(pixel.blue, 160, accuracy: 4)
    }

    func testMaskCompositeRecipeStepFingerprintTracksNamedOperations() throws {
        let baseMask = try makeTexture(pixel: [0, 0, 0, 255])
        let addMask = try makeTexture(pixel: [64, 0, 0, 255])
        let subtractMask = try makeTexture(pixel: [32, 0, 0, 255])
        let recipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseMask),
            steps: [
                MaskCompositeStep(
                    name: "subjectBoost",
                    mask: MaskDescriptor(texture: addMask, component: .red, blendMode: .add, opacity: 0.5)
                ),
                MaskCompositeStep(
                    name: "skySubtract",
                    mask: MaskDescriptor(texture: subtractMask, component: .red, blendMode: .subtract, opacity: 1)
                )
            ]
        )

        XCTAssertEqual(recipe.maskCount, 3)
        XCTAssertEqual(recipe.masks.count, 2)
        XCTAssertTrue(recipe.fingerprint.contains("base={base=1"))
        XCTAssertTrue(recipe.fingerprint.contains("name=subjectBoost"))
        XCTAssertTrue(recipe.fingerprint.contains("blend=2"))
        XCTAssertTrue(recipe.fingerprint.contains("name=skySubtract"))
        XCTAssertTrue(recipe.fingerprint.contains("blend=4"))
    }

    func testMaskDescriptorFactorsExposeComponentAndFeather() throws {
        let maskTexture = try makeTexture(pixel: [255, 128, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture,
            component: .red,
            blendMode: .multiply,
            featherPolicy: .normalized(0.4),
            opacity: 0.75
        )
        let filter = C7MaskRegionBlend(effectTexture: maskTexture, mask: descriptor)

        XCTAssertEqual(filter.factors[0], 0.75, accuracy: 0.0001)
        XCTAssertEqual(filter.factors[2], Float(MaskComponent.red.rawValue), accuracy: 0.0001)
        XCTAssertEqual(filter.factors[3], Float(MaskBlendMode.multiply.rawValue), accuracy: 0.0001)
        XCTAssertEqual(filter.factors[4], 0.4, accuracy: 0.0001)
    }

    private func makeTexture(pixel: [UInt8]) throws -> MTLTexture {
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
            XCTFail("Failed to create texture.")
            throw HarbethError.makeTexture
        }
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: pixel, bytesPerRow: 4)
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}
