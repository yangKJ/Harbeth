import XCTest
import Metal
@testable import Harbeth

final class RenderTaskTests: XCTestCase {

    func testTextureRenderTaskExposesCommandBufferStatusAndOutput() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [100, 80, 60, 255])
        let task = try HarbethIO(
            element: input,
            filter: C7Brightness(brightness: 0.1)
        ).startRenderTextureTask()

        let output = try task.output()

        XCTAssertEqual(task.commandBufferStatus, .completed)
        XCTAssertNil(task.error)
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(task.diagnostics?.compilationSource, .filtersPrimitive)
        XCTAssertEqual(task.diagnostics?.stageCount, 1)
    }

    func testRenderTaskCompletionObserverRunsAfterGPUCompletion() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [20, 40, 80, 255])
        let expectation = expectation(description: "render task completion")
        let task = try HarbethIO(
            element: input,
            filter: C7Contrast(contrast: 1.1)
        ).startRenderTextureTask()

        task.observeCompletion { completedTask in
            XCTAssertTrue(completedTask.isCompleted)
            XCTAssertEqual(completedTask.commandBufferStatus, .completed)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        _ = try task.output()
    }

    func testGenericRenderTextureTaskCarriesDerivativeDiagnostics() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [200, 20, 20, 255])
        let derivative = ImageDerivativeSpec(
            name: "taskDerivative",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .exact(C7Size(width: 2, height: 2))
        )

        let task = try HarbethIO<MTLTexture>(
            element: input,
            filters: []
        ).startRenderTextureTask(profile: .stablePreview, derivative: derivative)
        let output = try task.output()

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(task.diagnostics?.derivative.name, "taskDerivative")
        XCTAssertTrue(task.diagnostics?.containsDerivativeResize == true)
    }

    func testCompletedRenderTaskCanExportDiagnosticsJSON() throws {
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
        let task = RenderTask<MTLTexture>.completed(
            identifier: "completed-task",
            output: try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255]),
            diagnostics: diagnostics
        )

        let data = try task.diagnosticsJSONData(sortedKeys: true)
        let string = try task.diagnosticsJSONString(sortedKeys: true)

        XCTAssertEqual(String(data: data ?? Data(), encoding: .utf8), string)
        XCTAssertTrue(string?.contains("\"optimizationPlan\"") == true)
    }

    func testRenderTaskReturnsNilDiagnosticsJSONWhenAbsent() throws {
        let task = RenderTask<MTLTexture>.completed(
            identifier: "no-diagnostics",
            output: try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255]),
            diagnostics: nil
        )

        XCTAssertNil(try task.diagnosticsJSONData())
        XCTAssertNil(try task.diagnosticsJSONString())
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = Shared.shared.defaultDevice.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = pixel[0]
            pixels[index + 1] = pixel[1]
            pixels[index + 2] = pixel[2]
            pixels[index + 3] = pixel[3]
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }
}
