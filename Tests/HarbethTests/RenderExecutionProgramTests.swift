import Metal
import XCTest
@testable import Harbeth

final class RenderExecutionProgramTests: XCTestCase {
    override func setUp() {
        super.setUp()
        HarbethContext.shared.removeAllRenderPlans()
    }

    override func tearDown() {
        HarbethContext.shared.removeAllRenderPlans()
        super.tearDown()
    }

    func testProgramFreezesFusionAndDiagnosticsFromTheSameFilterChain() {
        let program = RenderExecutionCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1),
                C7Saturation(saturation: 0.9),
            ],
            inputSize: C7Size(width: 8, height: 6),
            profile: .stablePreview
        )

        XCTAssertEqual(program.filters.count, 1)
        XCTAssertEqual((program.filters.first as? C7FusedPointOperations)?.fusedOperationCount, 3)
        XCTAssertEqual(program.plan.graph.nodes.count, 1)
        XCTAssertEqual(program.diagnostics.nodes.count, 1)
        XCTAssertTrue(program.fingerprint.contains(program.diagnostics.graphFingerprint))
    }

    func testProgramCarriesPartialSamplerResolutionIntoExecutionAndDiagnostics() {
        let descriptor = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .repeat,
            tAddressMode: .repeat
        )
        let program = RenderExecutionCompiler.compile(
            filters: [C7Rotate(angle: 10)],
            inputSize: C7Size(width: 8, height: 6),
            samplerDescriptor: descriptor
        )
        let adapted = program.filters.first as? C7Rotate

        XCTAssertEqual(adapted?.samplingMode, .adaptive)
        XCTAssertEqual(adapted?.edgeMode, .repeat)
        XCTAssertEqual(program.diagnostics.samplerExecutionCoverage.mode, .partial)
        XCTAssertEqual(program.diagnostics.samplerExecutionCoverage.coveredFilterTypes, ["C7Rotate"])
        XCTAssertEqual(program.diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes, ["C7Rotate"])
    }

    func testProgramExpandsStageLifecycleIntoExecutableStepLiveness() {
        let program = RenderExecutionCompiler.compile(
            filters: [RenderGrayscale(), RenderSepia()],
            inputSize: C7Size(width: 8, height: 6),
            profile: .stablePreview
        )

        XCTAssertEqual(program.plan.optimizedStages.count, 1)
        XCTAssertEqual(program.steps.count, 2)
        XCTAssertEqual(program.steps.map(\.stageIndex), [0, 0])
        XCTAssertEqual(program.steps.map(\.lifecycleAction), [.reuseTransient, .allocatePersistentOutput])
    }

    func testProgramMaterializesDerivativeResizeAsExecutableStep() throws {
        let derivative = ImageDerivativeSpec(
            name: "execution-program-thumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: RenderProfile.stablePreview.defaultDerivativeSpec.semantic,
            outputSizePolicy: .maxPixelSize(4)
        )
        let texture = try makeTexture()
        let io = HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Brightness(brightness: 0.1)]
        ).configured(for: .stablePreview)
        let program = io.makeRenderProgram(input: texture, derivative: derivative)
        let output = try io.executeRenderProgram(input: texture, program: program)

        XCTAssertTrue(program.diagnostics.containsDerivativeResize)
        XCTAssertEqual(program.steps.count, 2)
        XCTAssertTrue(program.steps.last?.filter is C7Resize)
        let derivativeStep = try XCTUnwrap(program.steps.last)
        let derivativeLifecycle = try XCTUnwrap(
            program.diagnostics.optimizationPlan.lifecycleDecisions.first(where: {
                $0.stageIndex == derivativeStep.stageIndex
            })
        )
        XCTAssertEqual(derivativeStep.lifecycleAction, derivativeLifecycle.action)
        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(output.height, 3)
    }

    func testExecutorRejectsProgramFromDifferentFilterChain() throws {
        let texture = try makeTexture()
        let sourceIO = HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Brightness(brightness: 0.1)]
        ).configured(for: .stablePreview)
        let differentIO = HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Contrast(contrast: 1.1)]
        ).configured(for: .stablePreview)
        let program = sourceIO.makeRenderProgram(input: texture)

        XCTAssertThrowsError(try differentIO.executeRenderProgram(input: texture, program: program))
    }

    func testHarbethIOAndImageNodeUseTheSamePointwiseLowering() throws {
        let texture = try makeTexture()
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.1),
        ]
        let ioProgram = HarbethIO<MTLTexture>(element: texture, filters: filters)
            .configured(for: .stablePreview)
            .makeRenderProgram(input: texture)
        let nodePlan = try ImageNode.source(.texture(texture))
            .applying(filters: filters)
            .makeRenderPlan(profile: .stablePreview)

        XCTAssertEqual(ioProgram.filters.count, 1)
        XCTAssertEqual(ioProgram.diagnostics.nodes.count, 1)
        XCTAssertEqual(nodePlan.diagnostics.nodes.count, 1)
        XCTAssertEqual(ioProgram.diagnostics.nodes.first?.name, nodePlan.diagnostics.nodes.first?.name)
    }

    func testRenderTaskUsesSuppliedProgramDiagnostics() throws {
        let texture = try makeTexture()
        let io = HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Brightness(brightness: 0.1), C7Contrast(contrast: 1.1)]
        ).configured(for: .stablePreview)
        let program = io.makeRenderProgram(input: texture)
        let task = try io.startCompiledRenderTextureTask(program: program)

        _ = try task.output()
        XCTAssertEqual(task.diagnostics?.graphFingerprint, program.diagnostics.graphFingerprint)
        XCTAssertEqual(task.diagnostics?.nodes.count, program.filters.count)
    }

    func testCachedPlanIsRejectedWhenUnfingerprintedStructureChanges() {
        let cacheKey = "structural-cache-guard"
        let first = RenderExecutionCompiler.compile(
            filters: [UnfingerprintedResizeFilter(outputWidth: 4)],
            inputSize: C7Size(width: 8, height: 6),
            planCacheKey: cacheKey
        )
        let second = RenderExecutionCompiler.compile(
            filters: [UnfingerprintedResizeFilter(outputWidth: 6)],
            inputSize: C7Size(width: 8, height: 6),
            planCacheKey: cacheKey
        )

        XCTAssertEqual(first.sourceFilterFingerprint, second.sourceFilterFingerprint)
        XCTAssertFalse(second.reusedCachedPlan)
        XCTAssertEqual(second.diagnostics.outputSize, C7Size(width: 6, height: 6))
        XCTAssertEqual(second.steps.first?.outputSize, C7Size(width: 6, height: 6))
    }

    func testDeferredFramesCarryTheirPreparedDiagnosticsFingerprint() throws {
        let texture = try makeTexture()
        let ioRequest = try HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Brightness(brightness: 0.1)]
        ).makeRenderRequest()
        let nodeRequest = try ImageNode.texture(texture)
            .applying(C7Brightness(brightness: 0.1))
            .makeRenderRequest()
        let recipeRequest = try ImageNode.texture(texture)
            .editing(EditRecipe())
            .makeRenderRequest()

        let ioFrame = try ioRequest.renderFrame()
        let nodeFrame = try nodeRequest.renderFrame()
        let recipeFrame = try recipeRequest.renderFrame()

        XCTAssertEqual(ioFrame.metadata["renderGraphFingerprint"], ioRequest.diagnostics.graphFingerprint)
        XCTAssertEqual(nodeFrame.metadata["renderGraphFingerprint"], nodeRequest.diagnostics.graphFingerprint)
        XCTAssertEqual(recipeFrame.metadata["renderGraphFingerprint"], recipeRequest.diagnostics.graphFingerprint)
        XCTAssertNotNil(ioFrame.metadata["renderExecutionFingerprint"])
        XCTAssertNotNil(nodeFrame.metadata["renderExecutionFingerprint"])
        XCTAssertNotNil(recipeFrame.metadata["renderExecutionFingerprint"])
    }

    private func makeTexture() throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 8,
            height: 6,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Could not create Metal texture.")
        }
        return texture
    }
}

private struct UnfingerprintedResizeFilter: C7FilterProtocol {
    let outputWidth: Int

    var modifier: ModifierEnum {
        .compute(kernel: "C7Brightness")
    }

    func resize(input size: C7Size) -> C7Size {
        C7Size(width: outputWidth, height: size.height)
    }
}
