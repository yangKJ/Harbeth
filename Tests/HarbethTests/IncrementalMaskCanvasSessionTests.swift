//
//  IncrementalMaskCanvasSessionTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/26.
//

import CoreGraphics
import XCTest
@testable import Harbeth

final class IncrementalMaskCanvasSessionTests: XCTestCase {
    func testSessionSerializesIncrementalUpdatesAndRejectsStaleGeneration() async throws {
        let session = try IncrementalMaskCanvasSession(
            size: C7Size(width: 64, height: 64),
            identifier: "session-test"
        )

        let first = try await session.apply(
            points: [MaskBrushPoint(point: CGPoint(x: 0.2, y: 0.5))],
            generation: 3
        )
        let second = try await session.apply(
            points: [MaskBrushPoint(point: CGPoint(x: 0.8, y: 0.5))],
            generation: 4
        )

        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(second.revision, 2)
        do {
            _ = try await session.apply(points: [], generation: 2)
            XCTFail("Expected stale generation to fail")
        } catch {
            guard let harbethError = error as? HarbethError,
                  case .incrementalMaskCanvasStaleGeneration(let requested, let current) = harbethError else {
                return XCTFail("Expected HarbethError.incrementalMaskCanvasStaleGeneration, got \(error)")
            }
            XCTAssertEqual(requested, 2)
            XCTAssertEqual(current, 4)
        }
    }
}
