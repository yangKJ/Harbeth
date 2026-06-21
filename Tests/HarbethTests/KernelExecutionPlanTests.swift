import XCTest
@testable import Harbeth

final class KernelExecutionPlanTests: XCTestCase {

    func testComputeFilterExportsStableExecutionPlan() {
        let filter = C7Brightness(brightness: 0.2)
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(plan.kind, .compute)
        XCTAssertEqual(plan.inputTextureCount, 1)
        XCTAssertEqual(plan.passes.count, 1)
        XCTAssertEqual(plan.passes.first?.kind, .compute)
        XCTAssertFalse(plan.fingerprint.isEmpty)
    }

    func testInvocationCarriesExecutionPlanAndCompatibilitySummary() {
        let filter = C7Brightness(brightness: 0.1)
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))
        let invocation = descriptor.makeInvocation(filter: filter, inputSize: C7Size(width: 4, height: 4))

        XCTAssertEqual(invocation.kernelExecutionPlan.compatibilitySummary, "compatible")
        XCTAssertEqual(invocation.kernelExecutionPlan.passes.first?.functionIdentity.primaryName, "C7Brightness")
        XCTAssertTrue(invocation.fingerprint.contains(invocation.kernelExecutionPlan.fingerprint))
    }

    func testRenderFilterExecutionPlanTracksRenderPassKind() {
        let filter = RenderBasicFilter()
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 16, height: 12))

        XCTAssertEqual(plan.kind, .render)
        XCTAssertEqual(plan.passes.first?.kind, .render)
        XCTAssertEqual(plan.passes.first?.output.outputSize, C7Size(width: 16, height: 12))
        XCTAssertEqual(plan.passes.first?.drawCallCount, 1)
    }

    func testRenderExecutionPlanTracksMultiAttachmentOutputContract() {
        let filter = KernelExecutionMultiAttachmentRenderFilter()
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 16, height: 12))

        XCTAssertEqual(plan.kind, .render)
        XCTAssertEqual(plan.outputAttachmentCount, 2)
        XCTAssertEqual(plan.outputAttachmentSemantics, ["primaryColor", "analysis"])
        XCTAssertEqual(plan.outputAttachmentPixelFormats, ["rgba16Float", "rgba8Unorm"])
        XCTAssertEqual(plan.passes.first?.outputContract.attachmentCount, 2)
        XCTAssertTrue(plan.fingerprint.contains("outputAttachments=2"))
        XCTAssertTrue(plan.fingerprint.contains("outputAttachmentSemantics=primaryColor,analysis"))
        XCTAssertTrue(plan.fingerprint.contains("outputAttachmentPixels=rgba16Float,rgba8Unorm"))
    }

    func testKernelExecutionPlanIncludesExplicitParameterBindings() {
        let filter = KernelBindingComputeTestFilter()
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 8, height: 6))
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.parameterBindings.count, 2)
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "toneMatrix" && $0.dataType == .matrix3x3 }))
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "toneOffset" && $0.dataType == .float3 }))
        XCTAssertTrue(descriptor.fingerprint.contains("bindings=binding=toneMatrix"))
        XCTAssertTrue(plan.passes.first?.parameterFingerprint.contains("binding=toneMatrix") == true)
        XCTAssertTrue(plan.passes.first?.parameterFingerprint.contains("binding=toneOffset") == true)
    }
}

private struct KernelBindingComputeTestFilter: C7FilterProtocol {
    var modifier: ModifierEnum {
        .compute(kernel: "C7Brightness")
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "toneMatrix",
                index: 0,
                stage: .compute,
                value: .matrix3x3(.Kernel.identity)
            ),
            KernelParameterBinding(
                name: "toneOffset",
                index: 1,
                stage: .compute,
                value: .float3(SIMD3<Float>(0.1, 0.2, 0.3))
            )
        ]
    }
}

private struct KernelExecutionMultiAttachmentRenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            colorSpace: .extendedLinearSRGB,
            pixelFormat: .rgba16Float,
            additionalAttachments: [
                RenderOutputAttachmentContract(
                    index: 1,
                    semantic: .analysis,
                    alpha: .opaque,
                    colorSpace: .sRGB,
                    pixelFormat: .rgba8Unorm
                )
            ]
        )
    }
}
