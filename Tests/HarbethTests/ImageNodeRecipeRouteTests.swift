import XCTest
import Metal
import CoreMedia
import CoreVideo
@testable import Harbeth

final class ImageNodeRecipeRouteTests: XCTestCase {

    func testEditRecipeNodeProducesTextureFrameAndRequest() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let recipe = EditRecipe()
        let node = ImageNode
            .recipe(source: .texture(input), recipe: recipe)
            .applying(C7Brightness(brightness: -0.2))

        let texture = try node.makeTexture()
        let frame = try node.makeFrame(metadata: ["route": "recipe"])
        let request = try node.makeRenderRequest()

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.metadata["route"], "recipe")
        XCTAssertEqual(request.compilationSource, .editRecipe)
        XCTAssertEqual(request.source.kind, "texture")
    }

    func testMaskConvenienceNodePreservesEditRouteContracts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let gradient = MaskGradientRecipe(
            size: C7Size(width: 4, height: 4),
            kind: .linear(
                startPoint: CGPoint(x: 0, y: 0.5),
                endPoint: CGPoint(x: 1, y: 0.5)
            )
        )
        let node = try ImageNode
            .texture(input)
            .applying(
                mask: gradient,
                filters: [C7Brightness(brightness: -0.2)],
                component: .green,
                blendMode: .add,
                invert: true,
                featherPolicy: .normalized(0.15),
                opacity: 0.75
            )

        let request = try node.makeRenderRequest()
        let renderRecipe = try XCTUnwrap(request.renderRecipe)
        let snapshot = try node.makeDebugSnapshot()
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)

        XCTAssertEqual(request.compilationSource, .editRecipe)
        XCTAssertEqual(request.source.kind, "texture")
        XCTAssertEqual(renderRecipe.source.kind, "texture")
        XCTAssertEqual(snapshot.renderRecipe?.source.kind, "texture")
        XCTAssertEqual(localEffect.mask.kind, "maskGradientRecipe")
        XCTAssertEqual(localEffect.mask.component, .green)
        XCTAssertEqual(localEffect.mask.blendMode, .add)
        XCTAssertEqual(localEffect.mask.opacity, 0.75, accuracy: 0.0001)
    }

    func testLayerCompositeNodeProducesTextureFrameAndRequest() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let background = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))]
        )
        let node = ImageNode.layerComposite(recipe)

        let texture = try node.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let frame = try node.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["route": "layerComposite"])
        let request = try node.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(frame.metadata["route"], "layerComposite")
        XCTAssertEqual(request.compilationSource, .layerComposite)
        XCTAssertEqual(request.source.kind, "texture")
    }

    func testLayerCompositeNodePreservesSampleBufferSourceContractAcrossRequestRecipeAndSnapshot() throws {
        var sampleBuffer = try makeSampleBuffer(width: 2, height: 2, pixel: [255, 0, 0, 255])
        sampleBuffer.c7.isNotSync = true
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .sampleBuffer(sampleBuffer),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))]
        )
        let node = ImageNode.layerComposite(recipe)

        let request = try node.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)
        let snapshot = try node.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(request.source.kind, "sampleBuffer")
        XCTAssertEqual(request.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertEqual(renderRecipe.source.kind, "sampleBuffer")
        XCTAssertEqual(renderRecipe.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertEqual(snapshot.renderRecipe?.source.kind, "sampleBuffer")
        XCTAssertTrue(snapshot.summary.contains("origin=sampleBuffer"))
    }

    func testLayerCompositeNodeSamplerDescriptorReachesLayerLocalFilterExecution() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 0])
        let layer = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    filters: [RouteSamplerProbeFilter()],
                    normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            ]
        )

        let linearNode = ImageNode.layerComposite(recipe)
        let nearestNode = linearNode.withSamplerDescriptor(ImageSamplerDescriptor.nearest)

        let linearPixel = try firstPixel(in: linearNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative).texture)
        let nearestPixel = try firstPixel(in: nearestNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative).texture)

        XCTAssertNotEqual(linearPixel.red, nearestPixel.red)
        XCTAssertNotEqual(linearPixel.blue, nearestPixel.blue)
    }

    func testEditRouteSamplerCoverageCanBeMetadataOnlyForUnsupportedLegacyGeometryDescriptor() throws {
        let input = try makeTexture(width: 4, height: 2, pixel: [255, 0, 0, 255])
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let node = ImageNode
            .texture(input)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        cropRegion: ImageCropRegion(rect: CGRect(x: 1, y: 0, width: 2, height: 2))
                    )
                )
            )
            .withSamplerDescriptor(unsupported)

        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .metadataOnly)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, [])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Crop"])
    }

    func testEditRouteSamplerCoverageCanBeCoveredForRepresentableLegacyGeometryDescriptor() throws {
        let input = try makeTexture(width: 4, height: 2, pixel: [255, 0, 0, 255])
        let node = ImageNode
            .texture(input)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        rotationDegrees: 15
                    )
                )
            )
            .withSamplerDescriptor(.nearest)

        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .covered)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["C7Rotate"])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, [])
    }

    func testEditRouteSamplerCoverageCanBePartialAcrossRenderAndLegacyGeometryStages() throws {
        let input = try makeTexture(width: 4, height: 2, pixel: [255, 0, 0, 255])
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let node = ImageNode
            .texture(input)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        cropRegion: ImageCropRegion(rect: CGRect(x: 1, y: 0, width: 2, height: 2))
                    )
                )
            )
            .applying(RouteSamplerProbeFilter())
            .withSamplerDescriptor(unsupported)

        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .partial)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["RouteSamplerProbeFilter"])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Crop"])
    }

    func testLayerCompositeRouteSamplerCoverageCanBeCoveredForRenderLocalStage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 0])
        let layer = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    filters: [RouteSamplerProbeFilter()],
                    normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            ]
        )
        let node = ImageNode.layerComposite(recipe).withSamplerDescriptor(.nearest)

        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .covered)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["RouteSamplerProbeFilter"])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, [])
    }

    func testLayerCompositeRouteSamplerCoverageCanBeMetadataOnlyForUnsupportedLegacyLayerLocalGeometry() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 0])
        let layer = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    filters: [
                        C7Crop(
                            origin: C7Point2D(x: 0.5, y: 0),
                            width: 1,
                            height: 1,
                            samplingMode: .adaptive,
                            edgeMode: .transparent
                        )
                    ],
                    normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            ]
        )
        let node = ImageNode.layerComposite(recipe).withSamplerDescriptor(unsupported)

        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .metadataOnly)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, [])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Crop"])
    }

    func testLayerCompositeRouteSamplerCoverageCanBePartialAcrossRenderAndLegacyLayerLocalStages() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 0])
        let layer = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    filters: [
                        RouteSamplerProbeFilter(),
                        C7Crop(
                            origin: C7Point2D(x: 0.5, y: 0),
                            width: 1,
                            height: 1,
                            samplingMode: .adaptive,
                            edgeMode: .transparent
                        )
                    ],
                    normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            ]
        )
        let node = ImageNode.layerComposite(recipe).withSamplerDescriptor(unsupported)

        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .partial)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["RouteSamplerProbeFilter"])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Crop"])
    }

    func testEditRoutePointFiltersExposeMergedStageBenefit() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [255, 128, 64, 255])
        let node = ImageNode
            .texture(input)
            .editing(EditRecipe())
            .applying(filters: [
                C7Brightness(brightness: 0.08),
                C7Contrast(contrast: 1.05)
            ])

        let plan = try node.makeRenderPlan(profile: .stablePreview)

        XCTAssertEqual(plan.diagnostics.compilationSource, .editRecipe)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.mergedStageCount, 1)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.fusionEligibleNodeCount, 2)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("mergeCompatibleStages"))
        XCTAssertGreaterThanOrEqual(plan.diagnostics.stageCount, 1)
        XCTAssertTrue(plan.diagnostics.summary.contains("mergedStages="))
    }

    func testLayerCompositeRouteKeepsLayerLocalPreparationOutsideTopLevelMergeMetrics() throws {
        let background = try makeTexture(width: 4, height: 4, pixel: [8, 8, 8, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [240, 160, 80, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    filters: [
                        C7Brightness(brightness: 0.08),
                        C7Contrast(contrast: 1.05)
                    ],
                    normalizedFrame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
                )
            ]
        )

        let plan = try ImageNode.layerComposite(recipe).makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(plan.diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(plan.diagnostics.stageCount, 1)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.mergedStageCount, 0)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.fusionEligibleNodeCount, 0)
        XCTAssertFalse(plan.diagnostics.optimizationPlan.decisions.contains("mergeCompatibleStages"))
        XCTAssertTrue(plan.diagnostics.nodes.first?.name.contains("LayerComposite") == true)
    }

    func testEditRoutePersistentNodePreservesRecipeBoundaryAcrossOptimizedGraphAndSnapshot() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [255, 128, 64, 255])
        let node = ImageNode
            .texture(input)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: 3, height: 3),
                        aspectPolicy: .fit
                    )
                )
            )
            .applying(C7Brightness(brightness: 0.1))
            .withCachePolicy(.persistent)

        let optimized = try node.makeOptimizedImageGraph(profile: .stablePreview)
        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)
        let snapshot = try node.makeDebugSnapshot(profile: .stablePreview)

        XCTAssertTrue(optimized.graph.nodes.contains(where: { $0.kind == .recipe }))
        XCTAssertTrue(optimized.graph.persistentBoundaryCount >= 1)
        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(diagnostics.imageCachePolicy, .persistent)
        XCTAssertTrue(diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(snapshot.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertEqual(snapshot.diagnostics.compilationSource, RenderCompilationSource.editRecipe.rawValue)
    }

    func testEditRoutePersistentCachePolicyAddsPersistentBoundaryAndReservation() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [220, 120, 40, 255])
        let transientNode = ImageNode
            .texture(input)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: 3, height: 3),
                        aspectPolicy: .fit
                    )
                )
            )
            .applying(C7Brightness(brightness: 0.08))
        let persistentNode = transientNode.withCachePolicy(.persistent)

        let transientPlan = try transientNode.makeRenderPlan(profile: .stablePreview)
        let persistentPlan = try persistentNode.makeRenderPlan(profile: .stablePreview)

        XCTAssertEqual(transientPlan.diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(persistentPlan.diagnostics.compilationSource, .editRecipe)
        XCTAssertTrue(persistentPlan.diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .persistentOutput }))
        XCTAssertEqual(transientPlan.diagnostics.imageCachePolicy, .transient)
        XCTAssertEqual(persistentPlan.diagnostics.imageCachePolicy, .persistent)
        XCTAssertFalse(transientPlan.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(persistentPlan.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertLessThan(transientPlan.diagnostics.persistentBoundaryCount, persistentPlan.diagnostics.persistentBoundaryCount)
    }

    func testLayerCompositeRoutePersistentNodeExposesPrewarmReservations() throws {
        let background = try makeTexture(width: 4, height: 4, pixel: [16, 16, 16, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [240, 160, 80, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
                    opacity: 0.85
                )
            ]
        )
        let node = ImageNode.layerComposite(recipe).withCachePolicy(.persistent)

        let plan = try node.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)
        let snapshot = try node.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(plan.diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(plan.diagnostics.imageCachePolicy, .persistent)
        XCTAssertTrue(plan.diagnostics.persistentBoundaryCount >= 1)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .persistentOutput }))
        XCTAssertTrue(plan.diagnostics.summary.contains("prewarm="))
        XCTAssertEqual(snapshot.diagnostics.compilationSource, RenderCompilationSource.layerComposite.rawValue)
        XCTAssertTrue(snapshot.diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .persistentOutput }))
    }

    func testLayerCompositeRoutePersistentCachePolicyAddsPersistentReservationRelativeToTransientNode() throws {
        let background = try makeTexture(width: 4, height: 4, pixel: [24, 24, 24, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [255, 200, 120, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6))]
        )
        let transientNode = ImageNode.layerComposite(recipe)
        let persistentNode = transientNode.withCachePolicy(.persistent)

        let transientPlan = try transientNode.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)
        let persistentPlan = try persistentNode.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertTrue(persistentPlan.diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .persistentOutput }))
        XCTAssertEqual(transientPlan.diagnostics.imageCachePolicy, .transient)
        XCTAssertEqual(persistentPlan.diagnostics.imageCachePolicy, .persistent)
        XCTAssertFalse(transientPlan.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(persistentPlan.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertLessThan(transientPlan.diagnostics.persistentBoundaryCount, persistentPlan.diagnostics.persistentBoundaryCount)
    }

    func testTransitionRoutePersistentNodePreservesBoundaryAcrossGraphAndPlan() throws {
        let from = try makeTexture(width: 4, height: 4, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 4, height: 4, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let node = ImageNode.transition(recipe).withCachePolicy(.persistent)

        let optimized = try node.makeOptimizedImageGraph(profile: recipe.profile, derivative: recipe.derivative)
        let plan = try node.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertTrue(optimized.graph.nodes.contains(where: { $0.kind == .transition }))
        XCTAssertTrue(optimized.graph.persistentBoundaryCount >= 1)
        XCTAssertEqual(plan.diagnostics.compilationSource, .transition)
        XCTAssertEqual(plan.diagnostics.imageCachePolicy, .persistent)
        XCTAssertTrue(plan.diagnostics.containsTransitionKernel)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .persistentOutput }))
    }

    func testTransitionRouteSamplerCoverageCanBeCoveredForRenderStage() throws {
        let from = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let to = try makeTexture(width: 2, height: 1, pixelRows: [
            [0, 255, 0, 255],
            [255, 255, 0, 255]
        ])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let node = ImageNode.transition(recipe)
            .applying(RouteSamplerProbeFilter())
            .withSamplerDescriptor(.nearest)

        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(diagnostics.compilationSource, .transition)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .covered)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["RouteSamplerProbeFilter"])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, [])
    }

    func testTransitionRouteSamplerCoverageCanBePartialAcrossRenderAndLegacyGeometryStages() throws {
        let from = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let to = try makeTexture(width: 2, height: 1, pixelRows: [
            [0, 255, 0, 255],
            [255, 255, 0, 255]
        ])
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let node = ImageNode.transition(recipe)
            .applying(filters: [
                RouteSamplerProbeFilter(),
                C7Rotate(angle: 15)
            ])
            .withSamplerDescriptor(unsupported)

        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(diagnostics.compilationSource, .transition)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.mode, .partial)
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["RouteSamplerProbeFilter"])
        XCTAssertEqual(diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Rotate"])
    }

    func testTransitionRouteKeepsTransitionBoundaryWhileMergingTrailingPointFilters() throws {
        let from = try makeTexture(width: 4, height: 4, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 4, height: 4, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let node = ImageNode
            .transition(recipe)
            .applying(filters: [
                C7Brightness(brightness: 0.08),
                C7Contrast(contrast: 1.05)
            ])

        let plan = try node.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(plan.diagnostics.compilationSource, .transition)
        XCTAssertTrue(plan.diagnostics.containsTransitionKernel)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.stageCount, 2)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.mergedStageCount, 1)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("mergeCompatibleStages"))
        XCTAssertTrue(plan.diagnostics.summary.contains("mergedStages="))
    }

    func testTransitionRoutePersistentCachePolicyAddsPersistentReservationRelativeToTransientNode() throws {
        let from = try makeTexture(width: 4, height: 4, pixel: [255, 32, 32, 255])
        let to = try makeTexture(width: 4, height: 4, pixel: [32, 32, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let transientNode = ImageNode.transition(recipe)
        let persistentNode = transientNode.withCachePolicy(.persistent)

        let transientPlan = try transientNode.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)
        let persistentPlan = try persistentNode.makeRenderPlan(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(transientPlan.diagnostics.compilationSource, .transition)
        XCTAssertEqual(persistentPlan.diagnostics.compilationSource, .transition)
        XCTAssertTrue(persistentPlan.diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .persistentOutput }))
        XCTAssertEqual(transientPlan.diagnostics.imageCachePolicy, .transient)
        XCTAssertEqual(persistentPlan.diagnostics.imageCachePolicy, .persistent)
        XCTAssertFalse(transientPlan.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(persistentPlan.diagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertLessThan(transientPlan.diagnostics.persistentBoundaryCount, persistentPlan.diagnostics.persistentBoundaryCount)
    }

    func testTransitionNodeProducesTextureFrameAndDiagnostics() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let from = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 1
        )
        let node = ImageNode.transition(recipe)

        let texture = try node.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let frame = try node.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["route": "transition"])
        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(try firstPixel(in: frame.texture).blue, 255)
        XCTAssertEqual(frame.metadata["route"], "transition")
        XCTAssertEqual(diagnostics.compilationSource, .transition)
        XCTAssertTrue(diagnostics.containsTransitionKernel)
    }

    func testTransitionNodeConvenienceFactoryProducesTransitionRoute() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let from = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let node = ImageNode.transition(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 1
        )

        let request = try node.makeRenderRequest()
        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(request.compilationSource, .transition)
        XCTAssertEqual(request.source.kind, "texture")
        XCTAssertEqual(diagnostics.compilationSource, .transition)
        XCTAssertTrue(diagnostics.containsTransitionKernel)
    }

    func testTransitionNodePreservesSampleBufferSourceContractAcrossRequestRecipeAndSnapshot() throws {
        var sampleBuffer = try makeSampleBuffer(width: 2, height: 2, pixel: [255, 0, 0, 255])
        sampleBuffer.c7.isNotSync = true
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .sampleBuffer(sampleBuffer),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let node = ImageNode.transition(recipe)

        let request = try node.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)
        let snapshot = try node.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(request.source.kind, "sampleBuffer")
        XCTAssertEqual(request.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertEqual(renderRecipe.source.kind, "sampleBuffer")
        XCTAssertEqual(renderRecipe.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertEqual(snapshot.renderRecipe?.source.kind, "sampleBuffer")
        XCTAssertTrue(snapshot.summary.contains("origin=sampleBuffer"))
        XCTAssertEqual(request.compilationSource, .transition)
    }

    private func makeTexture(width: Int = 1, height: Int = 1, pixel: [UInt8]) throws -> MTLTexture {
        let bytes = Array(repeating: pixel, count: width * height)
        return try makeTexture(width: width, height: height, pixelRows: bytes)
    }

    private func makeSampleBuffer(width: Int, height: Int, pixel: [UInt8]) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create pixel buffer.")
            throw HarbethError.texture2Image
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            XCTFail("Missing base address.")
            throw HarbethError.texture2Image
        }
        let byteCount = CVPixelBufferGetDataSize(pixelBuffer)
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for index in stride(from: 0, to: byteCount, by: 4) {
            pointer[index] = pixel[2]
            pointer[index + 1] = pixel[1]
            pointer[index + 2] = pixel[0]
            pointer[index + 3] = pixel[3]
        }
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            throw HarbethError.texture2Image
        }
        return sampleBuffer
    }

    private func makeTexture(width: Int, height: Int, pixelRows: [[UInt8]]) throws -> MTLTexture {
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
        let bytes = pixelRows.flatMap { $0 }
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

private struct RouteSamplerProbeFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    func resize(input size: C7Size) -> C7Size {
        C7Size(width: 1, height: 1)
    }

    func setupVertices(inputSize: C7Size) -> [Float]? {
        [
            -1.0, -1.0, 0.375, 0.5,
             1.0, -1.0, 0.375, 0.5,
            -1.0,  1.0, 0.375, 0.5,
             1.0,  1.0, 0.375, 0.5
        ]
    }
}
