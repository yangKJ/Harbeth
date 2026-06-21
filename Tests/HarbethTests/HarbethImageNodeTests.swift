import XCTest
import Metal
@testable import Harbeth

final class HarbethImageNodeTests: XCTestCase {

    func testNodeFilterPathMatchesDirectFilterPath() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let filters: [C7FilterProtocol] = [C7Resize(width: 2, height: 2)]
        let node = HarbethImageNode.filters(input: .source(.texture(input)), filters: filters)

        let nodeOutput = try HarbethIO(element: input, filters: []).renderTexture(node: node)
        let directOutput: MTLTexture = try HarbethIO(element: input, filters: filters).output()
        let diagnostics = try HarbethIO(element: input, filters: []).renderDiagnostics(node: node)

        XCTAssertEqual(nodeOutput.width, directOutput.width)
        XCTAssertEqual(nodeOutput.height, directOutput.height)
        XCTAssertEqual(diagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(diagnostics.optimizationPlan.intermediateTextureCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("source=nodeGraph"))
    }

    func testNodeCachePolicyIsVisibleInDiagnostics() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let sourceDiagnostics = try HarbethImageNode.source(.texture(input)).makeDiagnostics()
        let persistentNode = HarbethImageNode
            .filters(input: .source(.texture(input)), filters: [C7Brightness(brightness: 0.1)])
            .withCachePolicy(.persistent)
        let persistentDiagnostics = try persistentNode.makeDiagnostics()

        XCTAssertEqual(sourceDiagnostics.imageCachePolicy, .persistent)
        XCTAssertEqual(persistentDiagnostics.imageCachePolicy, .persistent)
        XCTAssertTrue(persistentDiagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(persistentDiagnostics.summary.contains("cachePolicy=persistent"))
    }

    func testNodeSamplerDescriptorIsVisibleInDiagnostics() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let node = HarbethImageNode
            .source(.texture(input))
            .withSamplerDescriptor(.nearest)
        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(diagnostics.samplerDescriptor, .nearest)
        XCTAssertTrue(diagnostics.summary.contains("sampler=\(ImageSamplerDescriptor.nearest.fingerprint)"))
    }

    func testKernelDescriptorExposesStableFunctionAndContract() throws {
        let filter = C7Brightness(brightness: 0.2)
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.functionIdentity.kind, .compute)
        XCTAssertEqual(descriptor.functionIdentity.primaryName, "C7Brightness")
        XCTAssertEqual(descriptor.output.outputSize, C7Size(width: 8, height: 6))
        XCTAssertEqual(descriptor.resourceUsage, .singleInput)
        XCTAssertEqual(descriptor.resources.inputTextureCount, 1)
        XCTAssertEqual(descriptor.resources.memoryAccessPattern, "point")
        XCTAssertEqual(descriptor.alphaBehavior, .preserveInput)
        XCTAssertEqual(descriptor.outputContract.alpha, .preserveInput)
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "factors" && $0.dataType == .floatArray }))
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "memoryAccessPattern" && $0.role == .executionHint }))
        XCTAssertEqual(descriptor.passes.count, 1)
        XCTAssertEqual(descriptor.passes[0].functionIdentity.primaryName, "C7Brightness")
        XCTAssertTrue(descriptor.fingerprint.contains("filter=C7Brightness"))
        XCTAssertTrue(descriptor.fingerprint.contains("arguments=arg="))
        XCTAssertTrue(descriptor.fingerprint.contains("passes=pass=0"))
    }

    func testKernelDescriptorArgumentMetadataIsDeterministic() {
        let descriptor = C7Opacity(opacity: 0.4).kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let names = descriptor.arguments.map(\.name)
        let sortedNames = names.sorted()

        XCTAssertEqual(names, sortedNames)
        XCTAssertEqual(descriptor.arguments.first?.index, 0)
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "factors"
                && argument.role == .parameter
                && argument.dataType == .floatArray
                && argument.valueFingerprint == "floats:0.4000"
        }))
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "otherInputTextures"
                && argument.role == .inputTexture
                && argument.dataType == .int
                && argument.required == false
        }))
    }

    func testKernelDescriptorTracksAlphaAndResourceContracts() {
        let premultiply = C7PremultiplyAlpha().kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let unpremultiply = C7UnpremultiplyAlpha().kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let opacity = C7Opacity(opacity: 0.4).kernelDescriptor(inputSize: C7Size(width: 2, height: 2))

        XCTAssertEqual(premultiply.alphaBehavior, .outputsPremultiplied)
        XCTAssertEqual(premultiply.outputContract.alpha, .premultiplied)
        XCTAssertEqual(unpremultiply.alphaBehavior, .outputsNonPremultiplied)
        XCTAssertEqual(unpremultiply.outputContract.alpha, .nonPremultiplied)
        XCTAssertEqual(opacity.alphaBehavior, .modifiesAlpha)
        XCTAssertEqual(opacity.parameters["factors"]?.fingerprint, "floats:0.4000")
        XCTAssertTrue(opacity.fingerprint.contains("memory=auto"))
    }

    func testKernelNodeExecutesAlphaOutputContract() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [200, 100, 50, 128])
        let filter = C7Brightness(brightness: 0)
        let descriptor = HarbethKernelDescriptor(
            filterName: "identityPremultiply",
            functionIdentity: HarbethKernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            outputContract: RenderOutputContract(alpha: .forcePremultiply)
        )
        let node = HarbethImageNode.kernel(input: .source(.texture(input)), descriptor: descriptor, filter: filter)

        let output = try node.makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.red, 200)
        XCTAssertLessThan(outputPixel.green, 100)
        XCTAssertEqual(outputPixel.alpha, 128)
    }

    func testConservativeOptimizationPlanRecordsResourceDecisions() {
        let contract = RenderOutputContract(
            alpha: .forcePremultiply,
            pixelFormat: PixelFormatContract(pixelFormat: .rgba8Unorm, preservesInput: false)
        )
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ],
            inputSize: C7Size(width: 4, height: 4),
            profile: .readbackQuality,
            derivative: ImageDerivativeSpec(
                name: "testDerivative",
                renderIntent: .readback,
                sourceTier: .fullResolutionReusable,
                semantic: RenderProfile.readbackQuality.defaultImageSemantic,
                outputSizePolicy: .exact(C7Size(width: 2, height: 2))
            ),
            outputContract: contract
        )

        XCTAssertEqual(plan.diagnostics.outputContract.alpha, .forcePremultiply)
        XCTAssertEqual(plan.diagnostics.alphaConversionCount, 1)
        XCTAssertEqual(plan.diagnostics.pixelFormatConversionCount, 1)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.intermediateTextureCount, 2)
        XCTAssertGreaterThan(plan.diagnostics.optimizationPlan.estimatedTransientByteCount, 0)
        XCTAssertGreaterThan(plan.diagnostics.optimizationPlan.estimatedPersistentByteCount, 0)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.readbackBoundaryCount, 1)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.lifecycleDecisions.last?.action, .preserveForReadback)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("keepDerivativeResizeAtTerminalStage"))
        XCTAssertTrue(plan.diagnostics.summary.contains("transientBytes="))
    }

    func testOptimizerExposesTransientReuseLifecyclePlan() {
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1),
                C7Saturation(saturation: 0.8)
            ],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.diagnostics.optimizationPlan.lifecycleDecisions.count, plan.diagnostics.stageCount)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.lifecycleDecisions.contains(where: { $0.action == .allocatePersistentOutput }))
        XCTAssertTrue(plan.diagnostics.summary.contains("lifecycle="))
    }

    func testLayerCompositeRendersNormalizedFrameAndDiagnostics() throws {
        let background = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                    opacity: 1,
                    blendMode: .sourceOver
                )
            ]
        )
        let node = HarbethImageNode.layerComposite(recipe)

        let output = try HarbethIO(element: background, filters: []).renderTexture(node: node)
        let diagnostics = try HarbethIO(element: background, filters: []).renderDiagnostics(node: node)

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(try pixel(in: output, x: 0, y: 0).green, 255)
        XCTAssertEqual(try pixel(in: output, x: 1, y: 0).red, 255)
        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.nodes.first?.name.contains("C7LayerComposite"), true)
        XCTAssertEqual(diagnostics.optimizationPlan.destinationTextureCreationCount, 1)
    }

    func testLayerCompositeSupportsDifferenceBlendAndClampsFrame() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let imageLayer = ImageLayer(
            content: .texture(layer),
            normalizedFrame: CGRect(x: -0.25, y: -0.25, width: 2, height: 2),
            opacity: 1,
            blendMode: .difference
        )
        let recipe = LayerCompositeRecipe(background: .texture(background), layers: [imageLayer])

        let output = try HarbethImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(imageLayer.normalizedFrame, CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(outputPixel.red, 255)
        XCTAssertEqual(outputPixel.green, 255)
        XCTAssertEqual(outputPixel.blue, 0)
        XCTAssertTrue(recipe.fingerprint.contains("blend=8"))
    }

    func testNodeRecipeAndTransitionDiagnosticsKeepOriginalSources() throws {
        let from = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let recipeNode = HarbethImageNode.recipe(
            source: .texture(from),
            recipe: EditRecipe(filters: [C7Brightness(brightness: 0.1)]),
            mode: .preview
        )
        let transitionNode = HarbethImageNode.transition(
            TransitionRecipe(from: .texture(from), to: .texture(to), kernel: .dissolve, progress: 0.5)
        )

        let recipeDiagnostics = try HarbethIO(element: from, filters: []).renderDiagnostics(node: recipeNode)
        let transitionDiagnostics = try HarbethIO(element: from, filters: []).renderDiagnostics(node: transitionNode)

        XCTAssertEqual(recipeDiagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(transitionDiagnostics.compilationSource, .transition)
        XCTAssertTrue(transitionDiagnostics.containsTransitionKernel)
    }

    func testRenderOutputContractFingerprintAndAlphaExpectation() {
        let contract = RenderOutputContract(alpha: .forceUnpremultiply)

        XCTAssertEqual(contract.alpha.expectedAlphaType, .nonPremultiplied)
        XCTAssertTrue(contract.fingerprint.contains("alpha=forceUnpremultiply"))
        XCTAssertEqual(RenderOutputContract.preserveInput.alpha, .preserveInput)
    }

    private func makeTexture(width: Int = 1, height: Int = 1, pixel: [UInt8]) throws -> MTLTexture {
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
            throw XCTSkip("Could not create Metal texture.")
        }
        let bytes = Array(repeating: pixel, count: width * height).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func pixel(in texture: MTLTexture, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}
