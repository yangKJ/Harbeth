import XCTest
@testable import Harbeth

final class DiagnosticsContractTests: XCTestCase {
    override func tearDown() {
        HarbethLogger.handler = nil
        HarbethLogger.minimumLevel = .warning
        super.tearDown()
    }

    func testLoggerForwardsStructuredEventWithoutChangingDefaultCallShape() {
        let expectation = expectation(description: "structured event")
        let box = HarbethLogEventBox()
        HarbethLogger.minimumLevel = .debug
        HarbethLogger.handler = { event in
            box.store(event)
            expectation.fulfill()
        }

        HarbethLogger.log(
            .warning,
            origin: "harbethFilters",
            category: "metal-library",
            code: "harbeth_filters.metal.library.bundle_fallback",
            outcome: .fallback,
            metadata: ["source": "Bundle.main"],
            correlationID: "request-1",
            message: "fallback"
        )

        wait(for: [expectation], timeout: 1)
        let event = box.load()
        XCTAssertEqual(event?.origin, "harbethFilters")
        XCTAssertEqual(event?.code, "harbeth_filters.metal.library.bundle_fallback")
        XCTAssertEqual(event?.outcome, .fallback)
        XCTAssertEqual(event?.metadata["source"], "Bundle.main")
        XCTAssertEqual(event?.correlationID, "request-1")
    }

    func testEveryHarbethErrorFamilyProvidesStableDiagnosticCode() {
        XCTAssertEqual(HarbethError.readFunction("kernel").harbethDiagnosticCode, "harbeth.metal.function_not_found")
        XCTAssertEqual(HarbethError.textureSizeMismatch.harbethDiagnosticCode, "harbeth.texture.size_mismatch")
        XCTAssertEqual(HarbethError.viewSnapshotCaptureFailed("empty bounds").harbethDiagnosticCode, "harbeth.view_snapshot.capture_failed")
        XCTAssertEqual(HarbethError.textureMultiPassCancelled.harbethDiagnosticCode, "harbeth.texture_multi_pass.cancelled")
        XCTAssertEqual(HarbethError.textureRegionUnsupportedFootprint.harbethDiagnosticCode, "harbeth.texture_region.footprint_unsupported")
        XCTAssertEqual(HarbethError.readFunction("kernel").harbethDiagnosticMetadata["numericCode"], "1300")
        XCTAssertEqual(HarbethError.viewSnapshotCaptureFailed("empty bounds").harbethDiagnosticMetadata["reason"], "empty bounds")
    }

    func testExternalErrorBridgePreservesMachineReadablePipelineAndBudgetFacts() {
        let pipelineError: Error = HarbethError.pipelineBinaryArchiveFailed("archive unavailable")
        XCTAssertEqual(pipelineError.harbethDiagnosticCode, "harbeth.pipeline.binary_archive_failed")
        XCTAssertEqual(pipelineError.harbethDiagnosticMetadata["reason"], "archive unavailable")

        let admission = RenderResourceAdmission(
            estimate: RenderResourceEstimate(transientBytes: 1024, persistentBytes: 512, textureCount: 2, stageCount: 3),
            budget: RenderResourceBudget(maximumStageCount: 1),
            violations: [RenderResourceViolation(limit: .stageCount, estimated: 3, maximum: 1)]
        )
        let budgetError: Error = HarbethError.renderResourceBudgetExceeded(admission)

        XCTAssertEqual(budgetError.harbethDiagnosticCode, "harbeth.render.resource_budget_exceeded")
        XCTAssertEqual(budgetError.harbethDiagnosticMetadata["violations"], "stageCount")
        XCTAssertEqual(budgetError.harbethDiagnosticMetadata["budget"], "transient=unbounded|persistent=unbounded|total=unbounded|textures=unbounded|stages=1")
    }
}

private final class HarbethLogEventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var event: HarbethLogEvent?

    func store(_ event: HarbethLogEvent) {
        lock.lock()
        self.event = event
        lock.unlock()
    }

    func load() -> HarbethLogEvent? {
        lock.lock()
        defer { lock.unlock() }
        return event
    }
}
