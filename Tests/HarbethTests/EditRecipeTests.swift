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

    func testRecipeLocalEffectSupportsMaskCompositeRecipe() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let base = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let subtractMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let maskRecipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseMask, component: .red),
            steps: [
                MaskCompositeStep(
                    name: "subject-soft-subtract",
                    mask: MaskDescriptor(
                        texture: subtractMask,
                        component: .red,
                        blendMode: .subtract,
                        opacity: 1
                    )
                )
            ]
        )
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Brightness(brightness: -1)],
                    maskRecipe: maskRecipe
                )
            ]
        )

        let output = try HarbethIO(element: base, filters: [])
            .renderTexture(recipe: recipe)

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 128, accuracy: 4)
        XCTAssertEqual(pixel.green, 128, accuracy: 4)
        XCTAssertEqual(pixel.blue, 128, accuracy: 4)
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
        let diagnosticsString = try HarbethIO(element: input, filters: [])
            .renderDiagnosticsJSONString(recipe: recipe, mode: .preview, sortedKeys: true)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertTrue(diagnostics.containsLocalEffectComposite)
        XCTAssertFalse(diagnostics.containsTransitionKernel)
        XCTAssertTrue(diagnostics.summary.contains("source=editRecipe"))
        XCTAssertFalse(diagnostics.summary.contains("preview"))
        XCTAssertFalse(diagnostics.summary.contains("presentation"))
        XCTAssertTrue(diagnosticsString.contains("\"optimizationPlan\""))
    }

    func testRecipeDiagnosticsStayStableForMaskCompositeRecipeLocalEffect() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 2, height: 2, pixel: [200, 180, 160, 255])
        let baseMask = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let multiplyMask = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 255])
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Contrast(contrast: 1.1)],
                    maskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "intersection",
                                mask: MaskDescriptor(
                                    texture: multiplyMask,
                                    component: .red,
                                    blendMode: .multiply,
                                    opacity: 1
                                )
                            )
                        ]
                    )
                )
            ]
        )

        let diagnostics = try HarbethIO(element: input, filters: [])
            .renderDiagnostics(recipe: recipe, mode: .preview)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertTrue(diagnostics.containsLocalEffectComposite)
        XCTAssertTrue(diagnostics.nodes.contains(where: { $0.name.contains("C7MaskRegionBlend") }))
    }

    func testRecipeCompilationPlanAndNodePathStayAligned() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 4, height: 4, pixel: [120, 90, 60, 255])
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(targetSize: CGSize(width: 2, height: 2), aspectPolicy: .fit),
            filters: [C7Brightness(brightness: 0.1)]
        )

        let directPlan = try recipe.makeRenderPlan(source: .texture(input), mode: .preview)
        let nodePlan = try recipe.makeNode(source: .texture(input)).makeRenderPlan()
        let renderRecipe = try recipe.makeRenderRecipe(source: .texture(input), mode: .preview)

        XCTAssertEqual(directPlan.diagnostics.outputSize, nodePlan.diagnostics.outputSize)
        XCTAssertEqual(directPlan.diagnostics.stageCount, nodePlan.diagnostics.stageCount)
        XCTAssertEqual(directPlan.diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(renderRecipe.renderIntent, .stable)
        XCTAssertEqual(renderRecipe.source.kind, "texture")
        XCTAssertTrue(renderRecipe.filters.contains(where: { $0.stableTypeID.contains("C7Brightness") }))
    }

    func testRecipeRenderRecipeExposesLocalEffectMaskGraphDescriptor() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 2, height: 2, pixel: [120, 90, 60, 255])
        let baseMask = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let subtractMask = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 255])
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Brightness(brightness: -0.1)],
                    maskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "subtract-half",
                                mask: MaskDescriptor(
                                    texture: subtractMask,
                                    component: .red,
                                    blendMode: .subtract,
                                    opacity: 1
                                )
                            )
                        ]
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe(source: .texture(input), mode: .preview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)

        XCTAssertEqual(localEffect.mask.kind, "maskCompositeRecipe")
        XCTAssertEqual(localEffect.mask.stepCount, 1)
        XCTAssertEqual(localEffect.mask.steps.first?.name, "subtract-half")
        XCTAssertEqual(localEffect.mask.steps.first?.blendMode, .subtract)
    }

    func testRecipeRenderRecipePreservesGradientMaskDescriptor() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 3, height: 1, pixel: [120, 90, 60, 255])
        let recipe = EditRecipe(
            localEffects: [
                try LocalEffectRecipe(
                    filters: [C7Brightness(brightness: -0.1)],
                    maskGradientRecipe: MaskGradientRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .linear(
                            startPoint: CGPoint(x: 0, y: 0.5),
                            endPoint: CGPoint(x: 1, y: 0.5)
                        )
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe(source: .texture(input), mode: .preview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)

        XCTAssertEqual(localEffect.mask.kind, "maskGradientRecipe")
        XCTAssertEqual(localEffect.mask.gradient?.kind, "linear")
        XCTAssertTrue(localEffect.mask.gradient?.parameterValues.contains("size=3x1") == true)
        XCTAssertTrue(localEffect.mask.fingerprint.contains("kind=linear"))
    }

    func testRecipeRenderRecipePreservesParametricCompositeMaskStepDescriptors() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 3, height: 1, pixel: [120, 90, 60, 255])
        let baseGradient = MaskGradientRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .linear(
                startPoint: CGPoint(x: 0, y: 0.5),
                endPoint: CGPoint(x: 1, y: 0.5)
            )
        )
        let subtractShape = MaskShapeRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
        )
        let recipe = EditRecipe(
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Brightness(brightness: -0.1)],
                    maskRecipe: try MaskCompositeRecipe(
                        baseGradientRecipe: baseGradient
                    )
                    .subtracting(subtractShape, name: "centerSubtract")
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe(source: .texture(input), mode: .preview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)
        let step = try XCTUnwrap(localEffect.mask.steps.first)

        XCTAssertEqual(localEffect.mask.kind, "maskCompositeRecipe")
        XCTAssertEqual(localEffect.mask.gradient?.kind, "linear")
        XCTAssertEqual(step.name, "centerSubtract")
        XCTAssertEqual(step.blendMode, .subtract)
        XCTAssertEqual(step.shape?.kind, "rectangle")
    }

    func testRecipeRenderRecipePreservesShapeMaskDescriptor() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 3, height: 1, pixel: [120, 90, 60, 255])
        let recipe = EditRecipe(
            localEffects: [
                try LocalEffectRecipe(
                    filters: [C7Brightness(brightness: -0.1)],
                    maskShapeRecipe: MaskShapeRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe(source: .texture(input), mode: .preview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)

        XCTAssertEqual(localEffect.mask.kind, "maskShapeRecipe")
        XCTAssertEqual(localEffect.mask.shape?.kind, "rectangle")
        XCTAssertTrue(localEffect.mask.shape?.parameterValues.contains("size=3x1") == true)
    }

    func testLayerCompositeDirectPathMatchesNodePath() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let background = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let composite = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))]
        )
        let io = HarbethIO(element: background, filters: [])

        let directTexture = try io.renderTexture(composite: composite)
        let nodeTexture = try io.renderTexture(node: composite.makeNode())
        let diagnostics = try io.renderDiagnostics(composite: composite)
        let diagnosticsString = try io.renderDiagnosticsJSONString(composite: composite, sortedKeys: true)

        XCTAssertEqual(directTexture.width, nodeTexture.width)
        XCTAssertEqual(directTexture.height, nodeTexture.height)
        XCTAssertEqual(try firstPixel(in: directTexture).green, try firstPixel(in: nodeTexture).green)
        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.nodes.first?.name.contains("C7LayerComposite"), true)
        XCTAssertTrue(diagnosticsString.contains("\"optimizationPlan\""))
    }

    func testRecipeAndCompositeRenderRequestsExposeDeferredContracts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 2, height: 2, pixel: [120, 120, 120, 255])
        let recipe = EditRecipe(filters: [C7Brightness(brightness: 0.1)])
        let recipeRequest = try recipe.makeRenderRequest(source: .texture(input), mode: .preview)

        XCTAssertEqual(recipeRequest.compilationSource, .editRecipe)
        XCTAssertEqual(recipeRequest.source.kind, "texture")
        XCTAssertEqual(recipeRequest.renderRecipe?.renderIntent, .stable)
        XCTAssertEqual(try recipeRequest.renderTexture().width, 2)

        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let composite = LayerCompositeRecipe(
            background: .texture(input),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))]
        )
        let compositeRequest = try composite.makeRenderRequest()

        XCTAssertEqual(compositeRequest.compilationSource, .layerComposite)
        XCTAssertEqual(compositeRequest.source.kind, "texture")
        XCTAssertEqual(compositeRequest.renderRecipe?.source.kind, "texture")
        XCTAssertEqual(try compositeRequest.renderFrame(metadata: ["kind": "composite"]).metadata["kind"], "composite")
    }

    func testRecipeRenderRequestBridgesDeferredAttachmentOutputsThroughExtraFilters() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 2, height: 1, pixel: [120, 120, 120, 255])
        let recipe = EditRecipe(filters: [C7Brightness(brightness: 0.0)])
        let request = try recipe.makeRenderRequest(
            source: .texture(input),
            mode: .preview,
            extraFilters: [RenderAuxiliaryLuminance()]
        )

        let attachmentSet = try XCTUnwrap(request.renderAttachmentSet())
        let bundle = try XCTUnwrap(
            request.renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.channel, .luminance)
    }

    func testRecipeRenderRequestBridgesDeferredAnalysisBundleAndColorProbe() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 2, height: 1, pixel: [255, 0, 0, 255])
        let request = try EditRecipe(filters: [C7Brightness(brightness: 0.0)])
            .makeRenderRequest(source: .texture(input), mode: .preview)

        let bundle = try XCTUnwrap(
            request.renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                preferredMethod: .cpuReadback
            )
        )
        let probe = try XCTUnwrap(
            request.renderColorProbe(x: 0, y: 0)
        )

        XCTAssertEqual(bundle.statistics?.sampleCount, 2)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 2)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(bundle.attachmentDebugPolicies.map(\.label), ["primaryColor"])
    }

    func testRecipeRenderRequestBridgesDeferredColorRangeAnalysisScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 3, height: 1, pixels: [
            [255, 0, 0, 255],
            [0, 255, 0, 255],
            [255, 255, 255, 255]
        ])
        let request = try EditRecipe(filters: [C7Brightness(brightness: 0.0)])
            .makeRenderRequest(source: .texture(input), mode: .preview)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let bundle = try XCTUnwrap(
            request.renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let probe = try XCTUnwrap(request.renderColorProbe(scope: scope))

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.y, 0)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.z, 0)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
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

    private func makeTexture(width: Int, height: Int, pixels: [[UInt8]]) throws -> MTLTexture {
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
        let bytes = pixels.flatMap { $0 }
        XCTAssertEqual(bytes.count, width * height * 4)
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
