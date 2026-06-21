import XCTest
import Metal
@testable import Harbeth

final class RenderGraphTests: XCTestCase {

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
        XCTAssertEqual(plan.optimizedStages[0].nodeIndices, [0, 1])
        XCTAssertFalse(plan.optimizedStages[0].breaksFusion)
        XCTAssertEqual(plan.optimizedStages[1].filterCount, 1)
        XCTAssertTrue(plan.optimizedStages[1].breaksFusion)
        XCTAssertEqual(plan.optimizedStages[1].boundaryReason, .fusionBoundary)
        XCTAssertEqual(plan.optimizedStages[2].filterCount, 1)
        XCTAssertTrue(plan.debugSummary.contains("profile=responseLatency"))
        XCTAssertEqual(plan.diagnostics.inputSize, C7Size(width: 640, height: 480))
        XCTAssertEqual(plan.diagnostics.outputSize, C7Size(width: 320, height: 240))
        XCTAssertEqual(plan.diagnostics.stageCount, 3)
        XCTAssertEqual(plan.diagnostics.compilationSource, .filtersPrimitive)
        XCTAssertTrue(plan.diagnostics.containsDerivativeResize == false)
        XCTAssertEqual(plan.diagnostics.nodes.first?.inputSize, C7Size(width: 640, height: 480))
        XCTAssertEqual(plan.diagnostics.nodes[2].outputSize, C7Size(width: 320, height: 240))
        XCTAssertEqual(plan.diagnostics.nodes[2].parameterSummary["width"], "320.0")
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
    }
}
