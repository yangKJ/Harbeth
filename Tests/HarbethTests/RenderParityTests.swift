import XCTest
import Metal
@testable import Harbeth

final class RenderParityTests: XCTestCase {
    private func makeTexture() throws -> MTLTexture {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable.")
        }
        return try TextureLoader.makeTexture(
            width: 4,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "RenderParityTests"
        )
    }

    func testPreviewAndExportKeepVisualParityWhileReportingDeliveryDifferences() throws {
        let texture = try makeTexture()
        let io = HarbethIO(element: texture, filters: [
            C7Brightness(brightness: 0.15),
            C7Contrast(contrast: 1.08)
        ])
        let preview = try io.makeRenderRequest(profile: .stablePreview)
        let export = try io.makeRenderRequest(profile: .exportQuality)

        let report = preview.parityReport(comparedTo: export)

        XCTAssertTrue(report.isVisuallyEquivalent)
        XCTAssertFalse(report.isExactlyEquivalent)
        XCTAssertTrue(report.visualDifferences.isEmpty)
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .profile })
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .renderIntent })
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .derivative })
    }

    func testChangedEditOrSamplerIsReportedAsVisualDifference() throws {
        let texture = try makeTexture()
        let baseline = try ImageNode
            .source(.texture(texture))
            .applying(C7Brightness(brightness: 0.1))
            .makeRenderRequest()
        let changedEdit = try ImageNode
            .source(.texture(texture))
            .applying(C7Brightness(brightness: 0.3))
            .makeRenderRequest()
        let changedSampler = try ImageNode
            .source(.texture(texture))
            .applying(C7Brightness(brightness: 0.1))
            .withSamplerDescriptor(.nearest)
            .makeRenderRequest()

        let editReport = baseline.parityReport(comparedTo: changedEdit)
        let samplerReport = baseline.parityReport(comparedTo: changedSampler)

        XCTAssertFalse(editReport.isVisuallyEquivalent)
        XCTAssertTrue(editReport.visualDifferences.contains { $0.field == .processing })
        XCTAssertFalse(samplerReport.isVisuallyEquivalent)
        XCTAssertTrue(samplerReport.visualDifferences.contains { $0.field == .sampler })
    }

    func testRenderedFrameCarriesTheEvaluatedParityFingerprint() throws {
        let texture = try makeTexture()
        let request = try HarbethIO(element: texture, filters: [C7Brightness(brightness: 0.1)])
            .makeRenderRequest(profile: .stablePreview)

        let frame = try request.renderFrame(metadata: ["purpose": "parity-test"])

        XCTAssertEqual(frame.renderParityFingerprint, request.paritySignature.fingerprint)
        XCTAssertEqual(frame.metadata["purpose"], "parity-test")
    }
}
