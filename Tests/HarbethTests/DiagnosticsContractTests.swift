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
        XCTAssertEqual(TextureMultiPassError.cancelled.harbethDiagnosticCode, "harbeth.texture_multi_pass.cancelled")
        XCTAssertEqual(TextureRegionContextError.unsupportedFootprint.harbethDiagnosticCode, "harbeth.texture_region.footprint_unsupported")
        XCTAssertEqual(HarbethError.readFunction("kernel").harbethDiagnosticMetadata["numericCode"], "1300")
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
