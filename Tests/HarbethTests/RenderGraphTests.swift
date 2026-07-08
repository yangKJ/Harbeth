import XCTest
import Metal
@testable import Harbeth

final class RenderGraphTests: XCTestCase {

    func testPluginBoundaryAdapterStillMarksBoundaryStage() {
        let size = C7Size(width: 2, height: 2)
        let node = RenderNode(
            kind: .boundary,
            boundary: MockPluginBoundaryAdapter(capability: .cpu),
            outputSize: size,
            breaksFusion: true
        )
        let graph = RenderGraph(nodes: [node])
        let diagnostics = RenderNodeDiagnostic(
            index: 0,
            name: "PluginBoundary",
            kind: .boundary,
            inputSize: size,
            outputSize: size,
            breaksFusion: true,
            parameterSummary: ["capability": PluginBoundaryKind.cpu.rawValue]
        )
        let profile = RenderProfile.readbackQuality
        let plan = RenderPlan(
            graph: graph,
            profile: profile,
            derivative: profile.defaultDerivativeSpec,
            inputSize: size,
            outputSize: size,
            nodeDiagnostics: [diagnostics],
            compilationSource: .nodeGraph
        )

        XCTAssertTrue(plan.containsBoundary)
        XCTAssertTrue(plan.requiresCompletedGPUWork)
        XCTAssertEqual(plan.optimizedStages.first?.stageKind, .boundary)
        XCTAssertEqual(plan.optimizedStages.first?.boundaryReason, .externalBoundary)
        XCTAssertEqual(graph.nodes.first?.boundary?.capability, .cpu)
    }

    func testCompileLinearMetalFiltersIntoNativeNodes() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.2),
            C7Contrast(contrast: 1.1)
        ]
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 640, height: 480),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.graph.nodes.count, 2)
        XCTAssertEqual(plan.graph.nodes.map(\.kind), [.compute, .compute])
        XCTAssertFalse(plan.containsBoundary)
        XCTAssertFalse(plan.requiresCompletedGPUWork)
    }

    func testResizeMarksFusionBoundaryWithoutLeavingMetalGraph() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.2),
            C7Resize(width: 320, height: 240)
        ]
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 640, height: 480),
            profile: .exportQuality
        )

        XCTAssertEqual(plan.graph.nodes.map(\.kind), [.compute, .compute])
        XCTAssertEqual(plan.graph.nodes.last?.outputSize, C7Size(width: 320, height: 240))
        XCTAssertTrue(plan.graph.nodes.last?.breaksFusion ?? false)
        XCTAssertTrue(plan.containsBoundary)
        XCTAssertTrue(plan.requiresCompletedGPUWork)
        XCTAssertEqual(plan.optimizedStages.count, 2)
        XCTAssertEqual(plan.optimizedStages.last?.filterCount, 1)
    }

    func testHarbethIOExecutesResizeBoundaryFromRenderPlan() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let input = try TextureLoader.makeTexture(width: 8, height: 6, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "graph-resize-input")

        let output: MTLTexture = try HarbethIO(
            element: input,
            filters: [
                C7Resize(width: 4, height: 3),
                C7Brightness(brightness: 0.1)
            ]
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(output.height, 3)
    }

    func testOptimizerSplitsStagesAtFusionBoundaries() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.2),
            C7Contrast(contrast: 1.1),
            C7Resize(width: 320, height: 240),
            C7Gamma(gamma: 1.2)
        ]
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 640, height: 480),
            profile: .responseLatency
        )

        XCTAssertEqual(plan.optimizedStages.count, 3)
        XCTAssertEqual(plan.optimizedStages[0].filterCount, 2)
        XCTAssertEqual(plan.optimizedStages[0].stageKind, .compute)
        XCTAssertEqual(plan.optimizedStages[0].mergeClass, .pointCompute)
        XCTAssertEqual(plan.optimizedStages[0].nodeIndices, [0, 1])
        XCTAssertFalse(plan.optimizedStages[0].breaksFusion)
        XCTAssertEqual(plan.optimizedStages[1].filterCount, 1)
        XCTAssertTrue(plan.optimizedStages[1].breaksFusion)
        XCTAssertEqual(plan.optimizedStages[1].boundaryReason, .fusionBoundary)
        XCTAssertEqual(plan.optimizedStages[2].filterCount, 1)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.mergedStageCount >= 1)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.fusionEligibleNodeCount >= 2)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("mergeCompatibleStages"))
        XCTAssertTrue(plan.debugSummary.contains("profile=responseLatency"))
        XCTAssertEqual(plan.diagnostics.inputSize, C7Size(width: 640, height: 480))
        XCTAssertEqual(plan.diagnostics.outputSize, C7Size(width: 320, height: 240))
        XCTAssertEqual(plan.diagnostics.stageCount, 3)
        XCTAssertEqual(plan.diagnostics.compilationSource, .filtersPrimitive)
        XCTAssertTrue(plan.diagnostics.containsDerivativeResize == false)
        XCTAssertEqual(plan.diagnostics.nodes.first?.inputSize, C7Size(width: 640, height: 480))
        XCTAssertEqual(plan.diagnostics.nodes[2].outputSize, C7Size(width: 320, height: 240))
        XCTAssertEqual(plan.diagnostics.nodes[2].parameterSummary["width"], "320.0")
        XCTAssertFalse(plan.diagnostics.graphFingerprint.isEmpty)
        XCTAssertTrue(plan.diagnostics.summary.contains("graph="))
        XCTAssertEqual(plan.diagnostics.optimizationPlan.transientStageCount, 2)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.renderStageCount, 0)
    }

    func testImageGraphOptimizerPreservesSharedTransientFilterDependency() {
        let sourceID = ImageGraphNodeID(rawValue: 0)
        let sharedID = ImageGraphNodeID(rawValue: 1)
        let branchAID = ImageGraphNodeID(rawValue: 2)
        let branchBID = ImageGraphNodeID(rawValue: 3)
        let graph = ImageGraph(
            nodes: [
                .init(
                    id: sourceID,
                    kind: .source,
                    name: "Source.texture",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 0,
                    fingerprint: "source"
                ),
                .init(
                    id: sharedID,
                    kind: .filters,
                    name: "SharedFilters",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "shared"
                ),
                .init(
                    id: branchAID,
                    kind: .filters,
                    name: "BranchA",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "branch-a"
                ),
                .init(
                    id: branchBID,
                    kind: .filters,
                    name: "BranchB",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: "texture",
                    filterCount: 1,
                    fingerprint: "branch-b"
                )
            ],
            edges: [
                .init(from: sourceID, to: sharedID),
                .init(from: sharedID, to: branchAID),
                .init(from: sharedID, to: branchBID)
            ],
            rootNodeID: branchAID,
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec
        )

        let result = ImageGraphOptimizer.optimize(graph)

        XCTAssertEqual(graph.sharedDependencyNodeCount, 1)
        XCTAssertEqual(result.graph.sharedDependencyNodeCount, 1)
        XCTAssertEqual(result.graph.nodes.count, 4)
        XCTAssertEqual(result.graph.edges.count, 3)
        XCTAssertTrue(result.decisions.contains("preserveSharedInputDependency"))
        XCTAssertFalse(result.decisions.contains("mergeAdjacentFilterNodes"))
    }

    func testConfiguredProfilePropagatesIntoRenderPlan() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let input = try TextureLoader.makeTexture(width: 8, height: 6, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "graph-profile-input")

        let io = HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.05)
            ]
        ).configured(for: .exportQuality)

        XCTAssertEqual(io.renderProfile, .exportQuality)

        _ = try io.output()
    }

    func testHarbethIOReturnsStructuredRenderDiagnostics() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let input = try TextureLoader.makeTexture(width: 12, height: 10, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "graph-diagnostics-input")

        let io = HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Resize(width: 6, height: 5),
                C7Gamma(gamma: 1.3)
            ]
        )

        let diagnostics = try io.renderDiagnostics(profile: .inspectionQuality)
        let diagnosticsString = try io.renderDiagnosticsJSONString(profile: .inspectionQuality, sortedKeys: true)

        XCTAssertEqual(diagnostics.profile, .inspectionQuality)
        XCTAssertEqual(diagnostics.inputSize, C7Size(width: 12, height: 10))
        XCTAssertEqual(diagnostics.outputSize, C7Size(width: 6, height: 5))
        XCTAssertEqual(diagnostics.nodes.count, 3)
        XCTAssertEqual(diagnostics.stages.count, 3)
        XCTAssertEqual(diagnostics.stageCount, 3)
        XCTAssertTrue(diagnostics.containsBoundary)
        XCTAssertEqual(diagnostics.stages[1].outputSize, C7Size(width: 6, height: 5))
        XCTAssertEqual(diagnostics.compilationSource, .filtersPrimitive)
        XCTAssertTrue(diagnostics.summary.contains("output=6x5"))
        XCTAssertTrue(diagnostics.summary.contains("source=filtersPrimitive"))
        XCTAssertTrue(diagnostics.summary.contains("transientStages="))
        XCTAssertFalse(diagnostics.graphFingerprint.isEmpty)
        XCTAssertGreaterThanOrEqual(diagnostics.optimizationPlan.prewarmReservations.count, 2)
        XCTAssertTrue(diagnostics.optimizationPlan.prewarmReservations.contains(where: { $0.reason == .transientReuse }))
        XCTAssertTrue(diagnosticsString.contains("\"optimizationPlan\""))
    }

    func testHarbethIOAndImageNodeAlignOptimizationMetricsForEquivalentFilterChain() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let input = try TextureLoader.makeTexture(width: 12, height: 10, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "io-node-metrics-align-input")
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.05),
            C7Resize(width: 6, height: 5),
            C7Gamma(gamma: 1.3)
        ]

        let ioDiagnostics = try HarbethIO(element: input, filters: filters)
            .renderDiagnostics(profile: .inspectionQuality)
        let nodeDiagnostics = try ImageNode
            .texture(input)
            .applying(filters: filters)
            .makeDiagnostics(profile: .inspectionQuality)

        XCTAssertEqual(ioDiagnostics.compilationSource, .filtersPrimitive)
        XCTAssertEqual(nodeDiagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(ioDiagnostics.outputSize, nodeDiagnostics.outputSize)
        XCTAssertEqual(ioDiagnostics.stageCount, nodeDiagnostics.stageCount)
        XCTAssertEqual(ioDiagnostics.containsBoundary, nodeDiagnostics.containsBoundary)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.mergedStageCount, nodeDiagnostics.optimizationPlan.mergedStageCount)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.fusionEligibleNodeCount, nodeDiagnostics.optimizationPlan.fusionEligibleNodeCount)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.transientStageCount, nodeDiagnostics.optimizationPlan.transientStageCount)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.renderStageCount, nodeDiagnostics.optimizationPlan.renderStageCount)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.prewarmReservations, nodeDiagnostics.optimizationPlan.prewarmReservations)
        XCTAssertEqual(ioDiagnostics.samplerExecutionCoverage, nodeDiagnostics.samplerExecutionCoverage)
    }

    func testHarbethIOAndImageNodeAlignOptimizationMetricsForPointComputeChain() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let input = try TextureLoader.makeTexture(width: 8, height: 6, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "io-node-point-align-input")
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.05)
        ]

        let ioDiagnostics = try HarbethIO(element: input, filters: filters)
            .renderDiagnostics(profile: .stablePreview)
        let nodeDiagnostics = try ImageNode
            .texture(input)
            .applying(filters: filters)
            .makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(ioDiagnostics.optimizationPlan.mergedStageCount, 1)
        XCTAssertEqual(nodeDiagnostics.optimizationPlan.mergedStageCount, 1)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.fusionEligibleNodeCount, nodeDiagnostics.optimizationPlan.fusionEligibleNodeCount)
        XCTAssertEqual(ioDiagnostics.stageCount, 1)
        XCTAssertEqual(nodeDiagnostics.stageCount, 1)
        XCTAssertEqual(ioDiagnostics.optimizationPlan.prewarmReservations, nodeDiagnostics.optimizationPlan.prewarmReservations)
        XCTAssertEqual(ioDiagnostics.summary.contains("mergedStages=1"), nodeDiagnostics.summary.contains("mergedStages=1"))
    }

    func testOptimizerKeepsNeighborhoodComputeInSeparateStage() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7GaussianBlur(radius: 2),
            C7Contrast(contrast: 1.1)
        ]
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 640, height: 480),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.optimizedStages.count, 3)
        XCTAssertEqual(plan.optimizedStages[0].mergeClass, .pointCompute)
        XCTAssertNil(plan.optimizedStages[1].mergeClass)
        XCTAssertEqual(plan.optimizedStages[1].filterCount, 1)
        XCTAssertEqual(plan.optimizedStages[2].mergeClass, .pointCompute)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.mergedStageCount, 0)
        XCTAssertTrue(plan.diagnostics.summary.contains("mergedStages=0"))
    }

    func testDerivativeSpecCanResizeRenderPlanOutput() {
        let derivative = ImageDerivativeSpec(
            name: "panelThumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized),
            outputSizePolicy: .maxPixelSize(160)
        )
        let plan = GraphCompiler.compile(
            filters: [C7Brightness(brightness: 0.2)],
            inputSize: C7Size(width: 640, height: 480),
            profile: .stablePreview,
            derivative: derivative
        )

        XCTAssertEqual(plan.diagnostics.derivative.name, "panelThumbnail")
        XCTAssertEqual(plan.diagnostics.outputSize, C7Size(width: 160, height: 120))
        XCTAssertEqual(plan.graph.nodes.last?.outputSize, C7Size(width: 160, height: 120))
        XCTAssertTrue(plan.graph.nodes.last?.breaksFusion ?? false)
        XCTAssertEqual(plan.diagnostics.nodes.last?.name, "DerivativeResize")
        XCTAssertEqual(plan.diagnostics.nodes.last?.parameterSummary["derivative"], "panelThumbnail")
        XCTAssertTrue(plan.diagnostics.containsDerivativeResize)
        XCTAssertTrue(plan.diagnostics.stages.last?.containsDerivativeResize ?? false)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("keepDerivativeResizeAtTerminalStage"))
    }

    func testRenderStageDiagnosticsCountRenderStages() {
        let plan = GraphCompiler.compile(
            filters: [RenderBasicFilter()],
            inputSize: C7Size(width: 32, height: 24),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.optimizedStages.count, 1)
        XCTAssertEqual(plan.optimizedStages.first?.stageKind, .render)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.renderStageCount, 1)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.transientStageCount, 0)
        XCTAssertTrue(plan.diagnostics.graphFingerprint.contains("source=filtersPrimitive"))
    }

    func testOptimizationPlanExposesExecutablePrewarmReservations() {
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Resize(width: 16, height: 12),
                C7Contrast(contrast: 1.1)
            ],
            inputSize: C7Size(width: 32, height: 24),
            profile: .stablePreview,
            outputContract: .highPrecisionLinearTexture
        )

        let reservations = plan.diagnostics.optimizationPlan.prewarmReservations

        XCTAssertFalse(reservations.isEmpty)
        XCTAssertTrue(reservations.contains(where: { $0.reason == .transientReuse }))
        XCTAssertTrue(reservations.contains(where: { $0.reason == .persistentOutput }))
        XCTAssertTrue(reservations.contains(where: { $0.pixelFormat == .rgba16Float }))
        XCTAssertTrue(plan.diagnostics.summary.contains("prewarm="))
    }

    func testOptimizationPlanPreservesHighPrecisionInputPixelFormatForReservations() {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 32,
            kCVPixelBufferHeightKey: 24,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                32,
                24,
                kCVPixelFormatType_64RGBAHalf,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            return XCTFail("Failed to create RGBA16F pixel buffer.")
        }
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ],
            inputSize: C7Size(width: 32, height: 24),
            sourceDescriptor: ImageSource.pixelBuffer(pixelBuffer).descriptor
        )

        let reservations = plan.diagnostics.optimizationPlan.prewarmReservations

        XCTAssertFalse(reservations.isEmpty)
        XCTAssertTrue(reservations.contains(where: { $0.reason == .persistentOutput && $0.pixelFormat == .rgba16Float }))
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("preserveInputPixelFormatForReservations"))
    }

    func testOptimizationPlanCapsTransientReusePrewarmToDoubleBuffer() {
        let plan = GraphCompiler.compile(
            filters: [
                RenderBasicFilter(),
                C7Brightness(brightness: 0.1),
                RenderBasicFilter(),
                C7Contrast(contrast: 1.1),
                RenderBasicFilter()
            ],
            inputSize: C7Size(width: 32, height: 24),
            profile: .stablePreview
        )

        let transientReservation = plan.diagnostics.optimizationPlan.prewarmReservations.first {
            $0.reason == .transientReuse
        }

        XCTAssertEqual(plan.optimizedStages.count, 5)
        XCTAssertEqual(transientReservation?.stageIndices, [0, 1, 2, 3])
        XCTAssertEqual(transientReservation?.count, 2)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("capTransientReusePrewarmToDoubleBuffer"))
    }

    func testRenderPlanDerivesAttachmentDrivenHDRInputColorSpace() {
        let contract = PixelBufferContract(
            width: 32,
            height: 24,
            cvPixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            planeCount: 2,
            planar: true,
            colorModel: .yCbCrBiPlanar,
            nativeTextureLayout: .planeTextures,
            yCbCrMatrixAttachment: .ituR2020,
            colorPrimariesAttachment: .ituR2020,
            transferFunctionAttachment: .smpteSt2084PQ,
            planes: [
                .init(index: 0, width: 32, height: 24, bytesPerRow: 32, cvPixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, metalPixelFormat: .r8Unorm),
                .init(index: 1, width: 16, height: 12, bytesPerRow: 32, cvPixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, metalPixelFormat: .rg8Unorm)
            ]
        )
        let sourceDescriptor = ImageSourceDescriptor(
            kind: "pixelBuffer",
            sourceTier: .original,
            alphaType: .premultiplied,
            orientation: .up,
            cachePolicy: .persistent,
            pixelBufferContract: contract,
            pixelBufferBridgePlan: PixelBufferTextureBridgePlan(
                contract: contract,
                loadStrategy: .directPlaneTexture,
                preservesOwnerReference: true,
                planes: [
                    .init(index: 0, metalPixelFormat: .r8Unorm, conversionStrategy: .directMetalTexture, preservesOwnerReference: true),
                    .init(index: 1, metalPixelFormat: .rg8Unorm, conversionStrategy: .directMetalTexture, preservesOwnerReference: true)
                ]
            ),
            pixelBufferBridgePolicy: .directPlaneDecodeToRGBA,
            yCbCrDecodeContract: YCbCrDecodeContract(
                layout: .biPlanar,
                matrix: .bt2020VideoRange,
                componentBitDepth: 8,
                destinationPixelFormat: .rgba8Unorm
            )
        )

        let plan = GraphCompiler.compile(
            filters: [C7Brightness(brightness: 0.1)],
            inputSize: C7Size(width: 32, height: 24),
            sourceDescriptor: sourceDescriptor
        )

        XCTAssertEqual(plan.diagnostics.inputColorSpace.gamut, .ituR2020)
        XCTAssertEqual(plan.diagnostics.inputColorSpace.transferFunction, .perceptualQuantizer)
        XCTAssertEqual(plan.diagnostics.inputColorSpace.name, "ituR2020+smpteSt2084PQ")
        XCTAssertTrue(plan.diagnostics.inputIsHDRFriendly)
        XCTAssertTrue(plan.diagnostics.summary.contains("inputColor=ituR2020+smpteSt2084PQ"))
    }

    func testRenderPlanCanDeriveHDRInputColorSpaceFromYCbCrMatrixWithoutPrimaries() {
        let contract = PixelBufferContract(
            width: 32,
            height: 24,
            cvPixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            planeCount: 2,
            planar: true,
            colorModel: .yCbCrBiPlanar,
            nativeTextureLayout: .planeTextures,
            yCbCrMatrixAttachment: .ituR2020,
            colorPrimariesAttachment: nil,
            transferFunctionAttachment: .ituR2100HLG,
            planes: [
                .init(index: 0, width: 32, height: 24, bytesPerRow: 32, cvPixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, metalPixelFormat: .r8Unorm),
                .init(index: 1, width: 16, height: 12, bytesPerRow: 32, cvPixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, metalPixelFormat: .rg8Unorm)
            ]
        )
        let sourceDescriptor = ImageSourceDescriptor(
            kind: "pixelBuffer",
            sourceTier: .original,
            alphaType: .premultiplied,
            orientation: .up,
            cachePolicy: .persistent,
            pixelBufferContract: contract,
            pixelBufferBridgePlan: PixelBufferTextureBridgePlan(
                contract: contract,
                loadStrategy: .directPlaneTexture,
                preservesOwnerReference: true,
                planes: [
                    .init(index: 0, metalPixelFormat: .r8Unorm, conversionStrategy: .directMetalTexture, preservesOwnerReference: true),
                    .init(index: 1, metalPixelFormat: .rg8Unorm, conversionStrategy: .directMetalTexture, preservesOwnerReference: true)
                ]
            ),
            pixelBufferBridgePolicy: .directPlaneDecodeToRGBA,
            yCbCrDecodeContract: YCbCrDecodeContract(
                layout: .biPlanar,
                matrix: .bt2020VideoRange,
                componentBitDepth: 8,
                destinationPixelFormat: .rgba16Float
            )
        )

        let plan = GraphCompiler.compile(
            filters: [C7Brightness(brightness: 0.1)],
            inputSize: C7Size(width: 32, height: 24),
            sourceDescriptor: sourceDescriptor
        )

        XCTAssertEqual(plan.diagnostics.inputColorSpace.gamut, .ituR2020)
        XCTAssertEqual(plan.diagnostics.inputColorSpace.transferFunction, .hybridLogGamma)
        XCTAssertEqual(plan.diagnostics.inputColorSpace.name, "ituR2020+ituR2100HLG")
        XCTAssertTrue(plan.diagnostics.inputIsHDRFriendly)
    }

    func testOptimizationPlanEstimatesMoreBytesForHighPrecisionInputReservations() {
        var bgraPixelBuffer: CVPixelBuffer?
        var halfPixelBuffer: CVPixelBuffer?
        let sharedAttributes: [CFString: Any] = [
            kCVPixelBufferWidthKey: 32,
            kCVPixelBufferHeightKey: 24,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                32,
                24,
                kCVPixelFormatType_32BGRA,
                (sharedAttributes.merging([kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]) { $1 }) as CFDictionary,
                &bgraPixelBuffer
            ),
            kCVReturnSuccess
        )
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                32,
                24,
                kCVPixelFormatType_64RGBAHalf,
                (sharedAttributes.merging([kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf]) { $1 }) as CFDictionary,
                &halfPixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let bgraPixelBuffer, let halfPixelBuffer else {
            return XCTFail("Failed to create pixel buffer fixtures.")
        }

        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Resize(width: 16, height: 12),
            C7Contrast(contrast: 1.1)
        ]
        let bgraPlan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 32, height: 24),
            sourceDescriptor: ImageSource.pixelBuffer(bgraPixelBuffer).descriptor
        )
        let halfPlan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 32, height: 24),
            sourceDescriptor: ImageSource.pixelBuffer(halfPixelBuffer).descriptor
        )

        XCTAssertGreaterThan(
            halfPlan.diagnostics.optimizationPlan.estimatedTransientByteCount,
            bgraPlan.diagnostics.optimizationPlan.estimatedTransientByteCount
        )
        XCTAssertGreaterThan(
            halfPlan.diagnostics.optimizationPlan.estimatedPersistentByteCount,
            bgraPlan.diagnostics.optimizationPlan.estimatedPersistentByteCount
        )
    }

    func testDiagnosticsExposeAllocatorAndGraphMetrics() {
        Shared.shared.defaultTextureAllocator = ExactTextureAllocator(texturePool: Shared.shared.defaultTexturePool)
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ],
            inputSize: C7Size(width: 32, height: 24)
        )

        XCTAssertGreaterThanOrEqual(plan.diagnostics.graphNodeCount, 2)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.graphEdgeCount, 1)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.allocationStrategy, .exact)
        XCTAssertTrue(plan.diagnostics.summary.contains("allocator=exact"))
        XCTAssertTrue(plan.diagnostics.summary.contains("textureReuseRatio="))
    }

    func testDiagnosticsExposeRequestedAllocatorFallbackWhenHeapBackedFallsBack() {
        let allocator = TextureAllocationStrategy.heapBacked.makeAllocator(
            texturePool: Shared.shared.defaultTexturePool,
            heapTexturePoolSupported: false
        )
        Shared.shared.defaultTextureAllocator = allocator
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ],
            inputSize: C7Size(width: 32, height: 24)
        )

        XCTAssertEqual(plan.diagnostics.optimizationPlan.allocationStrategy, .exact)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.requestedAllocationStrategy, .heapBacked)
        XCTAssertEqual(
            plan.diagnostics.optimizationPlan.allocationFallbackReason,
            "unsupportedHeapTexturePoolCapabilityFallbackToExact"
        )
        XCTAssertEqual(plan.diagnostics.optimizationPlan.allocationResolution.requested, .heapBacked)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.allocationResolution.resolved, .exact)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.allocationResolution.isFallback)
        XCTAssertTrue(plan.diagnostics.summary.contains("allocator=exact"))
        XCTAssertTrue(plan.diagnostics.summary.contains("requestedAllocator=heapBacked"))
        XCTAssertTrue(plan.diagnostics.summary.contains("allocatorFallback=unsupportedHeapTexturePoolCapabilityFallbackToExact"))
    }

    func testOptimizationPlanReportsTextureReuseHitRatio() {
        let plan = RenderOptimizationPlan(
            intermediateTextureCount: 2,
            reusableTextureCount: 1,
            persistentOutputCount: 1,
            mergedStageCount: 0,
            fusionEligibleNodeCount: 0,
            transientStageCount: 1,
            renderStageCount: 0,
            estimatedTransientByteCount: 128,
            estimatedPersistentByteCount: 64,
            readbackBoundaryCount: 0,
            formatConversionCount: 0,
            destinationTextureCreationCount: 1,
            allocationStrategy: .tolerant,
            textureRequestCount: 4,
            textureReuseHitCount: 2,
            heapBackedAllocationCount: 0,
            prewarmReservations: [],
            lifecycleDecisions: [],
            decisions: ["planTransientTextureReuse"],
            allocatorDecisions: ["leaseToleranceMatch"]
        )

        XCTAssertEqual(plan.textureReuseHitRatio, 0.5, accuracy: 0.0001)
    }

    func testTextureAllocatorSnapshotReportsBoundedReuseHitRatio() {
        let empty = TextureAllocatorSnapshot(
            allocationStrategy: .exact,
            textureRequestCount: 0,
            textureReuseHitCount: 0,
            heapBackedAllocationCount: 0,
            allocatorDecisions: []
        )
        let saturated = TextureAllocatorSnapshot(
            allocationStrategy: .tolerant,
            textureRequestCount: 2,
            textureReuseHitCount: 4,
            heapBackedAllocationCount: 0,
            allocatorDecisions: ["leaseToleranceMatch"]
        )

        XCTAssertEqual(empty.textureReuseHitRatio, 0)
        XCTAssertEqual(saturated.textureReuseHitRatio, 1)
        XCTAssertEqual(empty.allocationResolution.fingerprint, "requested=exact|resolved=exact|fallback=none")
        XCTAssertEqual(saturated.allocationResolution.fingerprint, "requested=tolerant|resolved=tolerant|fallback=none")
    }

    func testRenderOptimizationPlanSupportsCodableRoundTrip() throws {
        let plan = RenderOptimizationPlan(
            intermediateTextureCount: 2,
            reusableTextureCount: 1,
            persistentOutputCount: 1,
            mergedStageCount: 1,
            fusionEligibleNodeCount: 2,
            transientStageCount: 1,
            renderStageCount: 0,
            estimatedTransientByteCount: 128,
            estimatedPersistentByteCount: 64,
            readbackBoundaryCount: 0,
            formatConversionCount: 1,
            destinationTextureCreationCount: 1,
            allocationStrategy: .heapBacked,
            textureRequestCount: 4,
            textureReuseHitCount: 2,
            heapBackedAllocationCount: 1,
            prewarmReservations: [
                RenderTextureReservation(
                    stageIndices: [0, 1],
                    size: C7Size(width: 16, height: 12),
                    pixelFormat: .rgba16Float,
                    reason: .transientReuse
                )
            ],
            lifecycleDecisions: [
                RenderTextureLifecycleDecision(
                    stageIndex: 0,
                    action: .reuseTransient,
                    size: C7Size(width: 16, height: 12),
                    reason: "safeTransientAfterStage"
                )
            ],
            decisions: ["planTransientTextureReuse"],
            allocatorDecisions: ["heapBackedAllocation"]
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(RenderOptimizationPlan.self, from: data)

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(decoded.textureReuseHitRatio, 0.5, accuracy: 0.0001)
    }

    func testRenderPlanDiagnosticsSupportsCodableRoundTrip() throws {
        let derivative = ImageDerivativeSpec(
            name: "previewDisplay",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .source
        )
        let diagnostics = RenderPlanDiagnostics(
            profile: .stablePreview,
            derivative: derivative,
            graphFingerprint: "graph=fingerprint",
            sourceKind: "texture",
            graphNodeCount: 2,
            graphEdgeCount: 1,
            optimizedGraphNodeCount: 2,
            graphOptimizationDecisions: ["preservePersistentImageNode"],
            persistentBoundaryCount: 1,
            transientReuseCandidateCount: 1,
            sharedDependencyNodeCount: 1,
            inputSize: C7Size(width: 16, height: 12),
            outputSize: C7Size(width: 16, height: 12),
            containsBoundary: true,
            requiresCompletedGPUWork: false,
            stageCount: 2,
            compilationSource: .nodeGraph,
            imageCachePolicy: .persistent,
            samplerDescriptor: ImageSamplerDescriptor.nearest,
            samplerExecutionCoverage: .init(mode: .covered, coveredFilterTypes: ["RenderBasicFilter"]),
            containsLocalEffectComposite: false,
            containsTransitionKernel: false,
            containsDerivativeResize: false,
            optimizationPlan: RenderOptimizationPlan(
                intermediateTextureCount: 2,
                reusableTextureCount: 1,
                persistentOutputCount: 1,
                mergedStageCount: 1,
                fusionEligibleNodeCount: 2,
                transientStageCount: 1,
                renderStageCount: 0,
                estimatedTransientByteCount: 128,
                estimatedPersistentByteCount: 64,
                readbackBoundaryCount: 0,
                formatConversionCount: 1,
                destinationTextureCreationCount: 1,
                allocationStrategy: .heapBacked,
                textureRequestCount: 4,
                textureReuseHitCount: 2,
                heapBackedAllocationCount: 1,
                prewarmReservations: [
                    RenderTextureReservation(
                        stageIndices: [0, 1],
                        size: C7Size(width: 16, height: 12),
                        pixelFormat: .rgba16Float,
                        reason: .transientReuse
                    )
                ],
                lifecycleDecisions: [
                    RenderTextureLifecycleDecision(
                        stageIndex: 0,
                        action: .reuseTransient,
                        size: C7Size(width: 16, height: 12),
                        reason: "safeTransientAfterStage"
                    )
                ],
                decisions: ["planTransientTextureReuse"],
                allocatorDecisions: ["heapBackedAllocation"]
            ),
            outputContract: .highPrecisionLinearTexture,
            inputColorSpace: .preserveInput,
            outputColorSpace: .extendedLinearSRGB,
            inputAlphaType: .premultiplied,
            outputAlphaType: .premultiplied,
            inputPixelFormat: .preserveInput,
            inputBridgePolicy: .directPlaneDecodeToRGBA,
            inputYCbCrDecodeContract: YCbCrDecodeContract(
                layout: .biPlanar,
                matrix: .bt601FullRange,
                componentBitDepth: 8,
                destinationPixelFormat: .rgba8Unorm
            ),
            outputPixelFormat: .rgba16Float,
            inputColorConversionCount: 0,
            inputPixelFormatConversionCount: 1,
            inputAlphaConversionCount: 0,
            inputDirectPlaneBridgeCount: 0,
            alphaConversionCount: 0,
            colorConversionCount: 1,
            pixelFormatConversionCount: 1,
            lossyConversionCount: 0,
            nodes: [
                RenderNodeDiagnostic(
                    index: 0,
                    name: "Input",
                    kind: .compute,
                    inputSize: C7Size(width: 16, height: 12),
                    outputSize: C7Size(width: 16, height: 12),
                    breaksFusion: false,
                    parameterSummary: [:]
                )
            ],
            stages: [
                RenderStage(
                    index: 0,
                    stageKind: .compute,
                    mergeClass: .pointCompute,
                    nodeIndices: [0],
                    kinds: [.compute],
                    filterCount: 1,
                    breaksFusion: false,
                    inputSize: C7Size(width: 16, height: 12),
                    outputSize: C7Size(width: 16, height: 12),
                    boundaryReason: nil,
                    containsReadbackBoundary: false,
                    createsDestinationTexture: true,
                    containsLocalEffectComposite: false,
                    containsTransitionKernel: false,
                    containsDerivativeResize: false
                )
            ]
        )

        let data = try JSONEncoder().encode(diagnostics)
        let decoded = try JSONDecoder().decode(RenderPlanDiagnostics.self, from: data)

        XCTAssertEqual(decoded, diagnostics)
        XCTAssertEqual(decoded.samplerDescriptor, ImageSamplerDescriptor.nearest)
        XCTAssertEqual(decoded.optimizationPlan.textureReuseHitRatio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.sharedDependencyNodeCount, 1)
        XCTAssertEqual(decoded.inputBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertEqual(decoded.inputYCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(decoded.inputYCbCrDecodeContract?.matrix, .bt601FullRange)
        XCTAssertTrue(decoded.summary.contains("sharedDependencies=1"))
        XCTAssertTrue(decoded.summary.contains("inputBridgePolicy=directPlaneDecodeToRGBA"))
        XCTAssertTrue(decoded.summary.contains("inputYCbCrDecode=layout=biPlanar|matrix=bt601FullRange|bitDepth=8"))
        XCTAssertFalse(decoded.inputIsHDRFriendly)
        XCTAssertEqual(decoded.inputPixelPrecision, .preserveInput)
    }

    func testRenderPlanDiagnosticsExportsStableJSONSurface() throws {
        let derivative = ImageDerivativeSpec(
            name: "previewDisplay",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .source
        )
        let diagnostics = RenderPlanDiagnostics(
            profile: .stablePreview,
            derivative: derivative,
            graphFingerprint: "graph=fingerprint",
            sourceKind: "texture",
            graphNodeCount: 1,
            graphEdgeCount: 0,
            optimizedGraphNodeCount: 1,
            graphOptimizationDecisions: [],
            persistentBoundaryCount: 0,
            transientReuseCandidateCount: 0,
            sharedDependencyNodeCount: 0,
            inputSize: C7Size(width: 8, height: 8),
            outputSize: C7Size(width: 8, height: 8),
            containsBoundary: false,
            requiresCompletedGPUWork: false,
            stageCount: 1,
            compilationSource: .filtersPrimitive,
            imageCachePolicy: .transient,
            samplerDescriptor: ImageSamplerDescriptor.nearest,
            samplerExecutionCoverage: .init(mode: .covered, coveredFilterTypes: ["RenderBasicFilter"]),
            containsLocalEffectComposite: false,
            containsTransitionKernel: false,
            containsDerivativeResize: false,
            optimizationPlan: RenderOptimizationPlan(
                intermediateTextureCount: 1,
                reusableTextureCount: 1,
                persistentOutputCount: 1,
                mergedStageCount: 0,
                fusionEligibleNodeCount: 1,
                transientStageCount: 1,
                renderStageCount: 0,
                estimatedTransientByteCount: 64,
                estimatedPersistentByteCount: 64,
                readbackBoundaryCount: 0,
                formatConversionCount: 0,
                destinationTextureCreationCount: 1,
                allocationStrategy: .exact,
                textureRequestCount: 2,
                textureReuseHitCount: 1,
                heapBackedAllocationCount: 0,
                prewarmReservations: [],
                lifecycleDecisions: [],
                decisions: ["singleStageNoOptimizationNeeded"],
                allocatorDecisions: ["dequeueExactMatch"]
            ),
            outputContract: .preserveInput,
            inputColorSpace: .preserveInput,
            outputColorSpace: .preserveInput,
            inputAlphaType: .premultiplied,
            outputAlphaType: .premultiplied,
            inputPixelFormat: .preserveInput,
            inputYCbCrDecodeContract: nil,
            outputPixelFormat: .preserveInput,
            inputColorConversionCount: 0,
            inputPixelFormatConversionCount: 0,
            inputAlphaConversionCount: 0,
            inputDirectPlaneBridgeCount: 0,
            alphaConversionCount: 0,
            colorConversionCount: 0,
            pixelFormatConversionCount: 0,
            lossyConversionCount: 0,
            nodes: [],
            stages: []
        )

        let data = try diagnostics.jsonData(sortedKeys: true)
        let string = try diagnostics.jsonString(sortedKeys: true)

        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        XCTAssertTrue(string.contains("\"optimizationPlan\""))
        XCTAssertTrue(string.contains("\"samplerDescriptor\""))
        XCTAssertTrue(string.contains("\"textureReuseHitCount\":1"))
        XCTAssertFalse(diagnostics.inputIsHDRFriendly)
        XCTAssertEqual(diagnostics.inputPixelPrecision, .preserveInput)
    }

    func testRenderPlanDiagnosticsSummarizeMultiAttachmentOutputContract() {
        let derivative = ImageDerivativeSpec(
            name: "previewDisplay",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .source
        )
        let contract = RenderOutputContract(
            colorSpace: .extendedLinearSRGB,
            pixelFormat: .rgba16Float,
            additionalAttachments: [
                RenderOutputAttachmentContract(
                    index: 1,
                    semantic: .luminance,
                    alpha: .opaque,
                    colorSpace: .displayP3,
                    pixelFormat: .rgba8Unorm
                )
            ]
        )
        let diagnostics = RenderPlanDiagnostics(
            profile: .stablePreview,
            derivative: derivative,
            graphFingerprint: "graph=fingerprint",
            sourceKind: "texture",
            graphNodeCount: 1,
            graphEdgeCount: 0,
            optimizedGraphNodeCount: 1,
            graphOptimizationDecisions: [],
            persistentBoundaryCount: 0,
            transientReuseCandidateCount: 0,
            sharedDependencyNodeCount: 0,
            inputSize: C7Size(width: 8, height: 8),
            outputSize: C7Size(width: 8, height: 8),
            containsBoundary: false,
            requiresCompletedGPUWork: false,
            stageCount: 1,
            compilationSource: .filtersPrimitive,
            imageCachePolicy: .transient,
            samplerDescriptor: .default,
            samplerExecutionCoverage: .init(mode: .notApplicable),
            containsLocalEffectComposite: false,
            containsTransitionKernel: false,
            containsDerivativeResize: false,
            optimizationPlan: RenderOptimizationPlan(
                intermediateTextureCount: 1,
                reusableTextureCount: 1,
                persistentOutputCount: 1,
                mergedStageCount: 0,
                fusionEligibleNodeCount: 1,
                transientStageCount: 1,
                renderStageCount: 0,
                estimatedTransientByteCount: 64,
                estimatedPersistentByteCount: 64,
                readbackBoundaryCount: 0,
                formatConversionCount: 1,
                destinationTextureCreationCount: 1,
                allocationStrategy: .exact,
                textureRequestCount: 2,
                textureReuseHitCount: 1,
                heapBackedAllocationCount: 0,
                prewarmReservations: [],
                lifecycleDecisions: [],
                decisions: [],
                allocatorDecisions: []
            ),
            outputContract: contract,
            inputColorSpace: .preserveInput,
            outputColorSpace: .extendedLinearSRGB,
            inputAlphaType: .premultiplied,
            outputAlphaType: .premultiplied,
            inputPixelFormat: .preserveInput,
            outputPixelFormat: .rgba16Float,
            inputColorConversionCount: 0,
            inputPixelFormatConversionCount: 0,
            inputAlphaConversionCount: 0,
            inputDirectPlaneBridgeCount: 0,
            alphaConversionCount: 0,
            colorConversionCount: 1,
            pixelFormatConversionCount: 1,
            lossyConversionCount: 0,
            nodes: [],
            stages: []
        )

        XCTAssertEqual(diagnostics.outputAttachmentCount, 2)
        XCTAssertTrue(diagnostics.outputHasMultipleAttachments)
        XCTAssertTrue(diagnostics.summary.contains("outputAttachments=2"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentIndices=0,1"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentSemantics=primaryColor,luminance"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentPixels=rgba16Float,rgba8Unorm"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentHDR=1,1"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentDebugLabels=primaryColor,luminance"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentDebugViews=color,monochrome"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentReadbackPixels=rgba16Float,rgba8Unorm"))
        XCTAssertTrue(diagnostics.summary.contains("outputAttachmentMonochromePreview=0,1"))
        XCTAssertTrue(diagnostics.summary.contains("hdrFriendly=1"))
        XCTAssertEqual(diagnostics.outputAttachmentDebugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(diagnostics.outputAttachmentDebugPolicies.map(\.interpretation), [.color, .monochrome])
    }

    func testSamplerExecutionCoverageReportsCoveredRenderPath() {
        let plan = GraphCompiler.compile(
            filters: [RenderBasicFilter()],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview,
            samplerDescriptor: .nearest
        )

        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.mode, .covered)
        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["RenderBasicFilter"])
        XCTAssertTrue(plan.diagnostics.summary.contains("samplerCoverage=covered"))
    }

    func testSamplerExecutionCoverageReportsCoveredLegacyComputeGeometryWhenDescriptorIsRepresentable() {
        let plan = GraphCompiler.compile(
            filters: [C7Rotate(angle: 15)],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview,
            samplerDescriptor: .nearest
        )

        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.mode, .covered)
        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["C7Rotate"])
        XCTAssertTrue(plan.diagnostics.summary.contains("samplerCoveredFilters=C7Rotate"))
    }

    func testSamplerExecutionCoverageReportsMetadataOnlyForUnsupportedLegacyComputeGeometryDescriptor() {
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let plan = GraphCompiler.compile(
            filters: [C7Rotate(angle: 15)],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview,
            samplerDescriptor: unsupported
        )

        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.mode, .metadataOnly)
        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Rotate"])
        XCTAssertTrue(plan.diagnostics.summary.contains("samplerMetadataOnlyFilters=C7Rotate"))
    }

    func testSamplerExecutionCoverageReportsMixedChainWhenDescriptorCannotBridgeAllStages() {
        let unsupported = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let plan = GraphCompiler.compile(
            filters: [RenderQuadTransform(), C7Rotate(angle: 15)],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview,
            samplerDescriptor: unsupported
        )

        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.mode, .metadataOnly)
        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.coveredFilterTypes, [])
        XCTAssertEqual(plan.diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Rotate", "RenderQuadTransform"])
    }

    func testExecutionPrewarmReservationsIncreaseTextureReuseForBoundaryChain() throws {
        Shared.shared.deinitDevice()
        _ = Shared.shared.defaultDevice
        Shared.shared.resetTexturePoolStatistics()

        let input = try TextureLoader.makeTexture(
            width: 8,
            height: 6,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "RenderGraphTests.prewarm.boundary.input"
        )

        let output: MTLTexture = try HarbethIO(
            element: input,
            filters: [
                C7Resize(width: 4, height: 3),
                C7Brightness(brightness: 0.1)
            ]
        ).output()

        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(output.height, 3)
        XCTAssertGreaterThan(Shared.shared.texturePoolStatistics?.totalTexturesReused ?? 0, 0)
    }

    func testExecutionPrewarmReservationsIncreaseTextureReuseForDoubleBufferChain() throws {
        Shared.shared.deinitDevice()
        _ = Shared.shared.defaultDevice
        Shared.shared.resetTexturePoolStatistics()

        let input = try TextureLoader.makeTexture(
            width: 8,
            height: 6,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "RenderGraphTests.prewarm.double-buffer.input"
        )

        let output: MTLTexture = try HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.05)
            ]
        ).output()

        XCTAssertEqual(output.width, 8)
        XCTAssertEqual(output.height, 6)
        XCTAssertGreaterThan(Shared.shared.texturePoolStatistics?.totalTexturesReused ?? 0, 0)
    }

    func testRenderGraphDebugSnapshotSupportsCodableRoundTrip() throws {
        let optimizationPlan = RenderOptimizationPlan(
            intermediateTextureCount: 2,
            reusableTextureCount: 1,
            persistentOutputCount: 1,
            mergedStageCount: 1,
            fusionEligibleNodeCount: 2,
            transientStageCount: 1,
            renderStageCount: 0,
            estimatedTransientByteCount: 128,
            estimatedPersistentByteCount: 64,
            readbackBoundaryCount: 0,
            formatConversionCount: 1,
            destinationTextureCreationCount: 1,
            allocationStrategy: .heapBacked,
            textureRequestCount: 4,
            textureReuseHitCount: 2,
            heapBackedAllocationCount: 1,
            prewarmReservations: [
                RenderTextureReservation(
                    stageIndices: [0, 1],
                    size: C7Size(width: 16, height: 12),
                    pixelFormat: .rgba16Float,
                    reason: .transientReuse
                )
            ],
            lifecycleDecisions: [
                RenderTextureLifecycleDecision(
                    stageIndex: 0,
                    action: .reuseTransient,
                    size: C7Size(width: 16, height: 12),
                    reason: "safeTransientAfterStage"
                )
            ],
            decisions: ["planTransientTextureReuse"],
            allocatorDecisions: ["heapBackedAllocation"]
        )
        let diagnostics = RenderGraphDebugSnapshot.Diagnostics(
            summary: "allocator=heapBacked textureReuseRatio=0.500",
            profile: "stablePreview",
            derivative: "Original",
            graphFingerprint: "graph=fingerprint",
            graphNodeCount: 2,
            graphEdgeCount: 1,
            optimizedGraphNodeCount: 2,
            graphOptimizationDecisions: ["preservePersistentImageNode"],
            persistentBoundaryCount: 1,
            transientReuseCandidateCount: 1,
            sharedDependencyNodeCount: 1,
            inputDirectPlaneBridgeCount: 0,
            inputBridgePolicy: "directPlaneDecodeToRGBA",
            inputYCbCrDecode: "layout=biPlanar|matrix=bt601FullRange|bitDepth=8|destPixel=70",
            runtimePreviewHostSummary: .init(
                report: PreviewHostExecutionReport(
                    predictedStrategy: .sampleBufferPassthroughHost,
                    actualBackingKind: .sampleBufferDisplayLayer,
                    actualResolvedHostStrategy: .sampleBufferPassthroughHost,
                    payloadMode: .passthrough,
                    state: .sampleBufferActive,
                    enqueueCount: 2,
                    visibilityPauseCount: 1,
                    visibilityResumeCount: 1,
                    strategySwitchCount: 1,
                    activationCount: 1
                ),
                fleet: PreviewHostFleetSnapshot(
                    activeHostCount: 2,
                    activeSampleBufferHostCount: 1,
                    activeMetalHostCount: 1,
                    suspendedHostCount: 0,
                    recoveringHostCount: 0,
                    fallbackHostCount: 0,
                    maxConcurrentSampleBufferHosts: 1,
                    totalStrategySwitchCount: 1,
                    totalActivationCount: 1,
                    totalDeactivationCount: 0,
                    totalRecoveryCount: 0,
                    totalFallbackCount: 0,
                    totalLifecycleSuspensionCount: 0,
                    totalVisibilitySuspensionCount: 1,
                    failureCountsByReason: [:]
                )
            ),
            inputPixelPrecision: "preserveInput",
            inputHDRFriendly: false,
            outputAttachmentLabels: ["primaryColor", "maskCoverage"],
            outputAttachmentDebugViews: ["color", "monochrome"],
            outputAttachmentReadbackPixelFormats: ["rgba8Unorm", "rgba8Unorm"],
            outputAttachmentMonochromePreviewFlags: [false, true],
            optimizationPlan: optimizationPlan,
            allocationStrategy: "heapBacked",
            textureRequestCount: 4,
            textureReuseHitCount: 2,
            textureReuseHitRatio: 0.5,
            heapBackedAllocationCount: 1,
            allocatorDecisions: ["heapBackedAllocation"],
            stageCount: 2,
            compilationSource: "nodeGraph",
            inputSize: "16x12",
            outputSize: "16x12"
        )
        let snapshot = RenderGraphDebugSnapshot(
            summary: diagnostics.summary,
            diagnostics: diagnostics,
            nodes: [
                .init(id: 0, kind: "source", name: "Input", cachePolicy: "transient", filterCount: 0, sourceKind: "texture"),
                .init(id: 1, kind: "compute", name: "Brightness", cachePolicy: "persistent", filterCount: 1, sourceKind: nil)
            ],
            edges: [
                .init(from: 0, to: 1, label: "input")
            ],
            optimizationDecisions: ["mergeCompatibleStages"],
            dotGraph: "digraph ImageGraph {\n  n0 -> n1 [label=\"input\"];\n}"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RenderGraphDebugSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.diagnostics.textureReuseHitRatio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.diagnostics.allocatorDecisions, ["heapBackedAllocation"])
        XCTAssertEqual(decoded.diagnostics.optimizationPlan, optimizationPlan)
        XCTAssertEqual(decoded.diagnostics.inputBridgePolicy, "directPlaneDecodeToRGBA")
        XCTAssertEqual(decoded.diagnostics.inputYCbCrDecode, "layout=biPlanar|matrix=bt601FullRange|bitDepth=8|destPixel=70")
        XCTAssertEqual(decoded.diagnostics.runtimePreviewHostSummary?.actualBackingKind, PreviewHostBackingKind.sampleBufferDisplayLayer.rawValue)
        XCTAssertEqual(decoded.diagnostics.runtimePreviewHostSummary?.fleetActiveSampleBufferHostCount, 1)
        XCTAssertEqual(decoded.diagnostics.inputPixelPrecision, "preserveInput")
        XCTAssertFalse(decoded.diagnostics.inputHDRFriendly)
        XCTAssertEqual(decoded.diagnostics.outputAttachmentLabels, ["primaryColor", "maskCoverage"])
        XCTAssertEqual(decoded.diagnostics.outputAttachmentDebugViews, ["color", "monochrome"])
        XCTAssertEqual(decoded.diagnostics.outputAttachmentReadbackPixelFormats, ["rgba8Unorm", "rgba8Unorm"])
        XCTAssertEqual(decoded.diagnostics.outputAttachmentMonochromePreviewFlags, [false, true])
        XCTAssertTrue(decoded.dotGraph.contains("digraph ImageGraph"))
    }

    func testRenderGraphDebugSnapshotExportsStableJSONSurface() throws {
        let optimizationPlan = RenderOptimizationPlan(
            intermediateTextureCount: 1,
            reusableTextureCount: 1,
            persistentOutputCount: 1,
            mergedStageCount: 0,
            fusionEligibleNodeCount: 1,
            transientStageCount: 1,
            renderStageCount: 0,
            estimatedTransientByteCount: 64,
            estimatedPersistentByteCount: 64,
            readbackBoundaryCount: 0,
            formatConversionCount: 0,
            destinationTextureCreationCount: 1,
            allocationStrategy: .exact,
            textureRequestCount: 2,
            textureReuseHitCount: 1,
            heapBackedAllocationCount: 0,
            prewarmReservations: [],
            lifecycleDecisions: [],
            decisions: ["singleStageNoOptimizationNeeded"],
            allocatorDecisions: ["dequeueExactMatch"]
        )
        let snapshot = RenderGraphDebugSnapshot(
            summary: "allocator=exact textureReuseRatio=0.500",
            diagnostics: .init(
                summary: "allocator=exact textureReuseRatio=0.500",
                profile: "stablePreview",
                derivative: "Original",
                graphFingerprint: "graph=fingerprint",
                graphNodeCount: 1,
                graphEdgeCount: 0,
                optimizedGraphNodeCount: 1,
                graphOptimizationDecisions: [],
                persistentBoundaryCount: 0,
                transientReuseCandidateCount: 0,
                sharedDependencyNodeCount: 0,
                inputDirectPlaneBridgeCount: 0,
                inputYCbCrDecode: nil,
                inputPixelPrecision: "preserveInput",
                inputHDRFriendly: false,
                outputAttachmentLabels: ["primaryColor"],
                outputAttachmentDebugViews: ["color"],
                outputAttachmentReadbackPixelFormats: ["rgba8Unorm"],
                outputAttachmentMonochromePreviewFlags: [false],
                optimizationPlan: optimizationPlan,
                allocationStrategy: "exact",
                textureRequestCount: 2,
                textureReuseHitCount: 1,
                textureReuseHitRatio: 0.5,
                heapBackedAllocationCount: 0,
                allocatorDecisions: ["dequeueExactMatch"],
                stageCount: 1,
                compilationSource: "filtersPrimitive",
                inputSize: "8x8",
                outputSize: "8x8"
            ),
            nodes: [
                .init(id: 0, kind: "source", name: "Input", cachePolicy: "transient", filterCount: 0, sourceKind: "texture")
            ],
            edges: [],
            optimizationDecisions: ["singleStageNoOptimizationNeeded"],
            dotGraph: "digraph ImageGraph {\n  n0 [label=\"Input\"];\n}"
        )

        let data = try snapshot.jsonData(sortedKeys: true)
        let string = try snapshot.jsonString(sortedKeys: true)

        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        XCTAssertTrue(string.contains("\"optimizationPlan\""))
        XCTAssertTrue(string.contains("\"allocationStrategy\":\"exact\""))
        XCTAssertTrue(string.contains("\"textureReuseHitRatio\":0.5"))
        XCTAssertTrue(string.contains("\"allocatorDecisions\":[\"dequeueExactMatch\"]"))
        XCTAssertTrue(string.contains("\"inputPixelPrecision\":\"preserveInput\""))
        XCTAssertTrue(string.contains("\"inputHDRFriendly\":false"))
        XCTAssertTrue(string.contains("\"outputAttachmentDebugViews\":[\"color\"]"))
        XCTAssertTrue(string.contains("\"outputAttachmentMonochromePreviewFlags\":[false]"))
        XCTAssertFalse(string.contains("\"runtimePreviewHostSummary\""))
    }

    func testRenderGraphDebugSnapshotPrettyPrintedJSONIsStable() throws {
        let snapshot = RenderGraphDebugSnapshot(
            summary: "allocator=exact textureReuseRatio=0.500",
            diagnostics: .init(
                summary: "allocator=exact textureReuseRatio=0.500",
                profile: "stablePreview",
                derivative: "Original",
                graphFingerprint: "graph=fingerprint",
                graphNodeCount: 1,
                graphEdgeCount: 0,
                optimizedGraphNodeCount: 1,
                graphOptimizationDecisions: [],
                persistentBoundaryCount: 0,
                transientReuseCandidateCount: 0,
                sharedDependencyNodeCount: 0,
                inputDirectPlaneBridgeCount: 0,
                inputYCbCrDecode: nil,
                inputPixelPrecision: "preserveInput",
                inputHDRFriendly: false,
                outputAttachmentLabels: ["primaryColor"],
                outputAttachmentDebugViews: ["color"],
                outputAttachmentReadbackPixelFormats: ["rgba8Unorm"],
                outputAttachmentMonochromePreviewFlags: [false],
                optimizationPlan: RenderOptimizationPlan(
                    intermediateTextureCount: 1,
                    reusableTextureCount: 1,
                    persistentOutputCount: 1,
                    mergedStageCount: 0,
                    fusionEligibleNodeCount: 1,
                    transientStageCount: 1,
                    renderStageCount: 0,
                    estimatedTransientByteCount: 64,
                    estimatedPersistentByteCount: 64,
                    readbackBoundaryCount: 0,
                    formatConversionCount: 0,
                    destinationTextureCreationCount: 1,
                    allocationStrategy: .exact,
                    textureRequestCount: 2,
                    textureReuseHitCount: 1,
                    heapBackedAllocationCount: 0,
                    prewarmReservations: [],
                    lifecycleDecisions: [],
                    decisions: ["singleStageNoOptimizationNeeded"],
                    allocatorDecisions: ["dequeueExactMatch"]
                ),
                allocationStrategy: "exact",
                textureRequestCount: 2,
                textureReuseHitCount: 1,
                textureReuseHitRatio: 0.5,
                heapBackedAllocationCount: 0,
                allocatorDecisions: ["dequeueExactMatch"],
                stageCount: 1,
                compilationSource: "filtersPrimitive",
                inputSize: "8x8",
                outputSize: "8x8"
            ),
            nodes: [
                .init(id: 0, kind: "source", name: "Input", cachePolicy: "transient", filterCount: 0, sourceKind: "texture")
            ],
            edges: [],
            optimizationDecisions: ["singleStageNoOptimizationNeeded"],
            dotGraph: "digraph ImageGraph {\n  n0 [label=\"Input\"];\n}"
        )

        let string = try snapshot.jsonString(prettyPrinted: true, sortedKeys: true)

        XCTAssertTrue(string.contains("\n"))
        XCTAssertTrue(string.contains("\"diagnostics\""))
        XCTAssertTrue(string.contains("\"optimizationPlan\""))
        XCTAssertTrue(string.contains("\"summary\" : \"allocator=exact textureReuseRatio=0.500\""))
        XCTAssertTrue(string.contains("\"inputPixelPrecision\" : \"preserveInput\""))
    }

    func testDebugSnapshotBuildsDOTGraphForNodePath() throws {
        let input = try TextureLoader.makeTexture(width: 8, height: 8, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "graph-snapshot-input")
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .applying(C7Contrast(contrast: 1.1))

        let snapshot = try node.makeDebugSnapshot()
        let jsonString = try snapshot.jsonString(
            prettyPrinted: false,
            sortedKeys: true
        )
        let diagnosticsString = try node.makeDiagnostics()
            .jsonString(
                prettyPrinted: false,
                sortedKeys: true
            )

        XCTAssertTrue(snapshot.dotGraph.contains("digraph ImageGraph"))
        XCTAssertFalse(snapshot.nodes.isEmpty)
        XCTAssertFalse(snapshot.optimizationDecisions.isEmpty)
        XCTAssertEqual(snapshot.diagnostics.allocationStrategy, Shared.shared.defaultTextureAllocator.strategy.rawValue)
        XCTAssertGreaterThanOrEqual(snapshot.diagnostics.textureRequestCount, 0)
        XCTAssertGreaterThanOrEqual(snapshot.diagnostics.textureReuseHitCount, 0)
        XCTAssertGreaterThanOrEqual(snapshot.diagnostics.textureReuseHitRatio, 0)
        XCTAssertLessThanOrEqual(snapshot.diagnostics.textureReuseHitRatio, 1)
        XCTAssertGreaterThanOrEqual(snapshot.diagnostics.heapBackedAllocationCount, 0)
        XCTAssertFalse(snapshot.diagnostics.allocatorDecisions.contains(where: \.isEmpty))
        XCTAssertEqual(snapshot.diagnostics.optimizationPlan.allocationStrategy.rawValue, snapshot.diagnostics.allocationStrategy)
        XCTAssertEqual(snapshot.diagnostics.inputPixelPrecision, "preserveInput")
        XCTAssertFalse(snapshot.diagnostics.inputHDRFriendly)
        XCTAssertTrue(jsonString.contains("\"optimizationPlan\""))
        XCTAssertTrue(diagnosticsString.contains("\"optimizationPlan\""))
    }

    func testDebugSnapshotTracksHalfFloatPixelBufferInputPrecision() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_64RGBAHalf,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        let node = ImageNode.source(.pixelBuffer(pixelBuffer))
        let snapshot = try node.makeDebugSnapshot()

        XCTAssertEqual(snapshot.diagnostics.inputPixelPrecision, "float16")
        XCTAssertTrue(snapshot.diagnostics.inputHDRFriendly)
        XCTAssertTrue(snapshot.summary.contains("inputPixelPrecision=float16"))
        XCTAssertTrue(snapshot.summary.contains("inputHDRFriendly=1"))
    }
}

private struct MockPluginBoundaryAdapter: PluginBoundaryAdapter {
    let capability: PluginCapability

    func render(input: RenderedFrame, context: PluginContext) throws -> RenderedFrame {
        input
    }
}
