//
//  TextureMultiPassExecutionTests.swift
//  HarbethTests
//

import XCTest
import CoreGraphics
import Metal
@testable import Harbeth

final class TextureMultiPassExecutionTests: XCTestCase {

    func testMultiPassExecutorRunsStagesAndKeepsOnlyFinalResult() throws {
        let source = try MaskTestHelpers.makeTexture(width: 4, height: 4, red: 96, alpha: 255)
        let result = try TextureMultiPassExecutor().execute(
            source: source,
            passes: [
                [C7Brightness(brightness: 0.1)],
                [C7Resize(width: 2, height: 2)]
            ]
        )

        XCTAssertEqual(result.completedPassCount, 2)
        XCTAssertEqual(C7Size(texture: result.texture), C7Size(width: 2, height: 2))
        result.release()
    }

    func testMultiPassExecutorTreatsEmptyStageAsNoOp() throws {
        let source = try MaskTestHelpers.makeTexture(width: 3, height: 2, red: 128, alpha: 255)
        let result = try TextureMultiPassExecutor().execute(source: source, passes: [[], []])

        XCTAssertTrue(result.texture === source)
        XCTAssertEqual(result.completedPassCount, 2)
        result.release()
    }

    func testMultiPassDiagnosticsExposeRegionFootprintAndResourceFacts() throws {
        let source = try MaskTestHelpers.makeTexture(width: 4, height: 4, red: 128, alpha: 255)
        let region = try TextureRegionContext(
            logicalExtent: CGRect(x: 0, y: 0, width: 4, height: 4),
            readRegion: CGRect(x: 1, y: 1, width: 2, height: 2),
            writeRegion: CGRect(x: 1, y: 1, width: 2, height: 2)
        )
        let result = try TextureMultiPassExecutor().execute(
            source: source,
            passes: [[C7Resize(width: 2, height: 2)]],
            region: region,
            footprint: .neighborhood(radius: 2),
            readbackOccurred: true
        )

        XCTAssertEqual(result.diagnostics.footprint, "neighborhood(2)")
        XCTAssertEqual(result.diagnostics.haloRadius, 2)
        XCTAssertEqual(result.diagnostics.logicalExtent?.width, 4)
        XCTAssertEqual(result.diagnostics.readRegion?.x, 1)
        XCTAssertEqual(result.diagnostics.writeRegion?.height, 2)
        XCTAssertEqual(result.diagnostics.passCount, 1)
        XCTAssertEqual(result.diagnostics.status, .completed)
        XCTAssertTrue(result.diagnostics.readbackOccurred)
        XCTAssertGreaterThan(result.diagnostics.estimatedByteCount, 0)
        XCTAssertGreaterThanOrEqual(result.diagnostics.durationMilliseconds ?? -1, 0)
        result.release()
    }

    func testMultiPassExecutorCancelsBeforeStartingAndReturnsNoPartialResult() throws {
        let source = try MaskTestHelpers.makeTexture(width: 4, height: 4, red: 128, alpha: 255)
        let token = TextureMultiPassCancellationToken()
        token.cancel()

        XCTAssertThrowsError(try TextureMultiPassExecutor().execute(
            source: source,
            passes: [[C7Brightness(brightness: 0.2)]],
            cancellation: token
        )) { error in
            XCTAssertEqual(error as? TextureMultiPassError, .cancelled)
        }
    }

    func testMultiPassExecutorDoesNotReturnPartialResultWhenAStageFails() throws {
        let source = try MaskTestHelpers.makeTexture(width: 4, height: 4, red: 128, alpha: 255)

        XCTAssertThrowsError(try TextureMultiPassExecutor().execute(
            source: source,
            passes: [
                [C7Brightness(brightness: 0.1)],
                [C7CropBlit(rect: CGRect(x: 0.5, y: 0, width: 2, height: 2))]
            ]
        ))
    }
}
