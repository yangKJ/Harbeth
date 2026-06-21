import XCTest
import Metal
@testable import Harbeth

final class EditRecipeTests: XCTestCase {

    func testPreviewAndFinalContractsRemainSeparated() {
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(targetSize: CGSize(width: 320, height: 180), aspectPolicy: .fit),
            filters: [C7Brightness(brightness: 0.2)],
            previewProfile: .stablePreview,
            finalProfile: .exportQuality
        )

        let preview = recipe.contract(for: .preview)
        let final = recipe.contract(for: .final)

        XCTAssertEqual(preview.profile, .stablePreview)
        XCTAssertEqual(preview.renderIntent, .stable)
        XCTAssertEqual(preview.sourceTier, .stableReusable)
        XCTAssertEqual(final.profile, .exportQuality)
        XCTAssertEqual(final.renderIntent, .export)
        XCTAssertEqual(final.sourceTier, .fullResolutionReusable)
    }

    func testEditRecipePrependsGeometryFilters() {
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(
                cropRegion: ImageCropRegion(rect: CGRect(x: 0, y: 0, width: 10, height: 10)),
                targetSize: CGSize(width: 5, height: 5),
                aspectPolicy: .fit
            ),
            filters: [C7Brightness(brightness: 0.2)]
        )

        let filters = recipe.makeFilterChain(inputSize: C7Size(width: 10, height: 10))
        XCTAssertGreaterThanOrEqual(filters.count, 3)
        XCTAssertEqual(filters.first?.kernelContract.functionIdentity, "compute:C7Crop")
        XCTAssertEqual(filters.last?.kernelContract.functionIdentity, "compute:C7Brightness")
    }

    func testRecipeDrivenFrameExecutionAppliesGeometryAndDerivativeContract() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let texture = try makeTexture(width: 8, height: 4, pixel: [255, 255, 255, 255])
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(
                targetSize: CGSize(width: 4, height: 4),
                aspectPolicy: .fit
            ),
            filters: [C7Brightness(brightness: -0.2)]
        )

        let frame = try HarbethIO(element: texture, filters: [])
            .renderFrame(recipe: recipe, mode: .preview, metadata: ["mode": "recipe"])

        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.renderIntent, .stable)
        XCTAssertEqual(frame.size.width, 4)
        XCTAssertEqual(frame.size.height, 4)
        XCTAssertEqual(frame.resolvedOutputSize, C7Size(width: 4, height: 4))
        XCTAssertEqual(frame.metadata["mode"], "recipe")
        XCTAssertFalse(frame.metadata["filterChainFingerprint"]?.isEmpty ?? true)
    }

    func testRecipeLocalEffectExecutesThroughMaskBlend() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let base = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let maskTexture = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Brightness(brightness: -1)],
                    mask: MaskDescriptor(texture: maskTexture, opacity: 1)
                )
            ]
        )

        let output = try HarbethIO(element: base, filters: [])
            .renderTexture(recipe: recipe)

        let pixel = try firstPixel(in: output)
        XCTAssertLessThan(pixel.red, 10)
        XCTAssertLessThan(pixel.green, 10)
        XCTAssertLessThan(pixel.blue, 10)
    }

    func testRecipeWithoutLocalEffectsMatchesDirectFilterExecution() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 1, height: 1, pixel: [180, 120, 80, 255])
        let recipe = EditRecipe(filters: [C7Brightness(brightness: -0.2)])

        let recipeOutput = try HarbethIO(element: input, filters: [])
            .renderTexture(recipe: recipe, mode: .preview)
        let directOutput: MTLTexture = try HarbethIO(
            element: input,
            filters: [C7Brightness(brightness: -0.2)]
        ).output()

        let recipePixel = try firstPixel(in: recipeOutput)
        let directPixel = try firstPixel(in: directOutput)
        XCTAssertEqual(recipePixel.red, directPixel.red)
        XCTAssertEqual(recipePixel.green, directPixel.green)
        XCTAssertEqual(recipePixel.blue, directPixel.blue)
        XCTAssertEqual(recipePixel.alpha, directPixel.alpha)
    }

    func testMultipleLocalEffectsRunInStableOrder() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 1, height: 1, pixel: [200, 200, 200, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(filters: [C7Brightness(brightness: -0.15)], mask: MaskDescriptor(texture: mask, opacity: 1)),
                LocalEffectRecipe(filters: [C7Brightness(brightness: -0.15)], mask: MaskDescriptor(texture: mask, opacity: 1))
            ]
        )

        let output = try HarbethIO(element: input, filters: [])
            .renderTexture(recipe: recipe)
        let pixel = try firstPixel(in: output)

        XCTAssertLessThan(pixel.red, 150)
        XCTAssertLessThan(pixel.green, 150)
        XCTAssertLessThan(pixel.blue, 150)
    }

    func testEmptyLocalEffectFilterChainKeepsRecipeStable() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 1, height: 1, pixel: [120, 80, 40, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(filters: [], mask: MaskDescriptor(texture: mask, opacity: 1))
            ]
        )

        let output = try HarbethIO(element: input, filters: []).renderTexture(recipe: recipe)
        let outputPixel = try firstPixel(in: output)

        XCTAssertEqual(outputPixel.red, 120)
        XCTAssertEqual(outputPixel.green, 80)
        XCTAssertEqual(outputPixel.blue, 40)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testFinalRecipeContractDrivesFrameMetadata() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 4, height: 4, pixel: [255, 255, 255, 255])
        let finalDerivative = ImageDerivativeSpec(
            name: "finalDelivery",
            renderIntent: .export,
            sourceTier: .fullResolutionReusable,
            semantic: ImageSemanticDescriptor(role: .output, purpose: .export, fidelity: .fullResolution),
            outputSizePolicy: .exact(C7Size(width: 2, height: 2))
        )
        let recipe = EditRecipe(
            filters: [C7Brightness(brightness: -0.1)],
            finalProfile: .exportQuality,
            finalDerivative: finalDerivative
        )

        let frame = try HarbethIO(element: input, filters: [])
            .renderFrame(recipe: recipe, mode: .final)

        XCTAssertEqual(frame.profile, .exportQuality)
        XCTAssertEqual(frame.renderIntent, .export)
        XCTAssertEqual(frame.derivative.name, "finalDelivery")
        XCTAssertEqual(frame.sourceTier, .original)
        XCTAssertEqual(frame.semantic.purpose, .export)
        XCTAssertEqual(frame.resolvedOutputSize, C7Size(width: 2, height: 2))
    }

    func testRecipeDiagnosticsExposeRecipeAndLocalEffectContracts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 4, height: 4, pixel: [255, 255, 255, 255])
        let recipe = EditRecipe(
            filters: [C7Brightness(brightness: 0.1)],
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Contrast(contrast: 1.1)],
                    mask: MaskDescriptor(texture: input, opacity: 1)
                )
            ]
        )

        let diagnostics = try HarbethIO(element: input, filters: [])
            .renderDiagnostics(recipe: recipe, mode: .preview)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertTrue(diagnostics.containsLocalEffectComposite)
        XCTAssertFalse(diagnostics.containsTransitionKernel)
        XCTAssertTrue(diagnostics.summary.contains("source=editRecipe"))
        XCTAssertFalse(diagnostics.summary.contains("preview"))
        XCTAssertFalse(diagnostics.summary.contains("presentation"))
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create texture.")
            throw HarbethError.makeTexture
        }
        let row = Array(repeating: pixel, count: width).flatMap { $0 }
        let bytes = Array(repeating: row, count: height).flatMap { $0 }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
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
