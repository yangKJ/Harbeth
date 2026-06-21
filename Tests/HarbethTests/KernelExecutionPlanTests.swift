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
    }
}
