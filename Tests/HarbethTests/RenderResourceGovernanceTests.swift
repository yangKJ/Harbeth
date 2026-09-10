import XCTest
import Metal
@testable import Harbeth

final class RenderResourceGovernanceTests: XCTestCase {
    private func makeRequest() throws -> RenderRequest {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let texture = try TextureLoader.makeTexture(
            width: 16,
            height: 12,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "RenderResourceGovernanceTests"
        )
        return try HarbethIO(element: texture, filters: [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.05)
        ]).makeRenderRequest(profile: .stablePreview)
    }

    func testEstimateComesFromTheCompiledOptimizationPlan() throws {
        let request = try makeRequest()
        let plan = request.diagnostics.optimizationPlan

        XCTAssertEqual(request.resourceEstimate.transientBytes, plan.estimatedTransientByteCount)
        XCTAssertEqual(request.resourceEstimate.persistentBytes, plan.estimatedPersistentByteCount)
        XCTAssertEqual(request.resourceEstimate.totalBytes, plan.estimatedTransientByteCount + plan.estimatedPersistentByteCount)
        XCTAssertEqual(request.resourceEstimate.stageCount, request.diagnostics.stageCount)
        XCTAssertTrue(request.resourceAdmission.isAccepted)
    }

    func testRejectedBudgetFailsBeforeTextureOrFrameExecution() throws {
        let request = try makeRequest().withResourceBudget(
            RenderResourceBudget(maximumStageCount: 0)
        )

        XCTAssertFalse(request.resourceAdmission.isAccepted)
        XCTAssertEqual(request.resourceAdmission.violations.map(\.limit), [.stageCount])

        XCTAssertThrowsError(try request.renderTexture()) { error in
            guard let harbethError = error as? HarbethError,
                  case .renderResourceBudgetExceeded(let admission) = harbethError else {
                return XCTFail("Expected HarbethError.renderResourceBudgetExceeded, got \(error).")
            }
            XCTAssertEqual(harbethError.harbethDiagnosticCode, "harbeth.render.resource_budget_exceeded")
            XCTAssertEqual(admission.violations.first?.maximum, 0)
        }
        XCTAssertThrowsError(try request.renderFrame())
    }

    func testAcceptedBudgetIsTracedIntoFrameMetadata() throws {
        let budget = RenderResourceBudget(
            maximumTotalBytes: Int.max,
            maximumTextureCount: Int.max,
            maximumStageCount: Int.max
        )
        let request = try makeRequest().withResourceBudget(budget)

        let frame = try request.renderFrame()

        XCTAssertEqual(frame.metadata["renderResourceBudget"], budget.fingerprint)
        XCTAssertEqual(frame.metadata["renderResourceEstimate"], request.resourceEstimate.fingerprint)
    }

    func testMeasuredRenderReportsAllocatorRequestsAndBytes() throws {
        let request = try makeRequest().withResourceBudget(
            RenderResourceBudget(maximumTotalBytes: Int.max)
        )

        let result = try request.renderFrameWithResourceReport()
        let observation = result.report.observation

        XCTAssertTrue(result.report.admission.isAccepted)
        XCTAssertGreaterThan(observation.textureRequestCount, 0)
        XCTAssertGreaterThan(observation.allocationCount + observation.reuseCount, 0)
        XCTAssertGreaterThan(observation.allocatedBytes + observation.reusedBytes, 0)
        XCTAssertEqual(result.output.metadata["renderResourceEstimate"], request.resourceEstimate.fingerprint)
    }
}
