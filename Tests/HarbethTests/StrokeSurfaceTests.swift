//
//  StrokeSurfaceTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/26.
//

import CoreGraphics
import XCTest
@testable import Harbeth

final class StrokeSurfaceTests: XCTestCase {
    private final class PredictedResults: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [UInt64: Result<RenderedFrame?, HarbethError>] = [:]

        func record(_ result: Result<RenderedFrame?, HarbethError>, generation: UInt64) {
            lock.withLock { values[generation] = result }
        }

        func snapshot() -> [UInt64: Result<RenderedFrame?, HarbethError>] {
            lock.withLock { values }
        }
    }

    func testActualAndPredictedLayersUseIndependentTextures() async throws {
        let surface = try StrokeSurface(size: C7Size(width: 64, height: 64), identifier: "stroke-surface-layers")
        let style = StrokeSurfaceStyle(
            width: 0.1,
            color: StrokeSurfaceColor(red: 0.2, green: 0.3, blue: 0.4)
        )

        let actual = try await surface.appendActual(
            points: [MaskBrushPoint(point: CGPoint(x: 0.2, y: 0.3))],
            style: style,
            generation: 3
        )
        let predicted = try await replacePredicted(
            surface: surface,
            points: [MaskBrushPoint(point: CGPoint(x: 0.6, y: 0.7))],
            style: style,
            generation: 5
        )

        let predictedFrame = try XCTUnwrap(predicted)
        XCTAssertFalse(actual.texture === predictedFrame.texture)
        XCTAssertEqual(actual.token.generation, 3)
        XCTAssertEqual(predictedFrame.token.generation, 5)
        XCTAssertEqual(actual.metadata["strokeLayer"], "actual")
        XCTAssertEqual(predictedFrame.metadata["strokeLayer"], "predicted")
    }

    func testPredictedGenerationRejectsOlderReplacement() async throws {
        let surface = try StrokeSurface(size: C7Size(width: 32, height: 32), identifier: "stroke-surface-generation")
        let style = StrokeSurfaceStyle(width: 0.1, color: StrokeSurfaceColor(red: 0, green: 0, blue: 0))

        _ = try await replacePredicted(
            surface: surface,
            points: [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))],
            style: style,
            generation: 4
        )

        do {
            _ = try await replacePredicted(surface: surface, points: [], style: style, generation: 3)
            XCTFail("Expected stale predicted generation to be rejected")
        } catch {
            guard let harbethError = error as? HarbethError,
                  case .strokeSurfaceStalePredictedGeneration(let requested, let current) = harbethError else {
                return XCTFail("Expected HarbethError.strokeSurfaceStalePredictedGeneration, got \(error)")
            }
            XCTAssertEqual(requested, 3)
            XCTAssertEqual(current, 4)
        }
    }

    func testRapidPredictedUpdatesOnlyDeliverLatestGeneration() async throws {
        let surface = try StrokeSurface(size: C7Size(width: 2_048, height: 2_048), identifier: "stroke-surface-latest-only")
        let style = StrokeSurfaceStyle(width: 0.08, color: StrokeSurfaceColor(red: 0.1, green: 0.2, blue: 0.3))
        let completions = expectation(description: "predicted completions")
        completions.expectedFulfillmentCount = 3
        let results = PredictedResults()

        for generation in 1 ... 3 {
            try await surface.replacePredicted(
                points: [MaskBrushPoint(point: CGPoint(x: 0.1 * Double(generation), y: 0.5))],
                style: style,
                generation: UInt64(generation)
            ) { result in
                results.record(result, generation: UInt64(generation))
                completions.fulfill()
            }
        }

        await fulfillment(of: [completions], timeout: 5)
        let completedResults = results.snapshot()
        XCTAssertNil(try completedResults[1]?.get())
        XCTAssertNil(try completedResults[2]?.get())
        let latest = try XCTUnwrap(try completedResults[3]?.get())
        XCTAssertEqual(latest.token.generation, 3)
        XCTAssertEqual(latest.metadata["strokeLayer"], "predicted")
    }

    func testRealtimeSurfaceBoundsLongCanvasWithoutChangingAspectRatio() async throws {
        let surface = try StrokeSurface(size: C7Size(width: 8_881, height: 2_960), identifier: "stroke-surface-bounds")
        let frame = try await surface.appendActual(
            points: [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))],
            style: StrokeSurfaceStyle(width: 0.1, color: StrokeSurfaceColor(red: 0, green: 0, blue: 0)),
            generation: 1
        )

        XCTAssertLessThanOrEqual(frame.texture.width, 8_192)
        XCTAssertLessThanOrEqual(frame.texture.height, 8_192)
        XCTAssertEqual(
            Double(frame.texture.width) / Double(frame.texture.height),
            8_881.0 / 2_960.0,
            accuracy: 0.002
        )
    }

    private func replacePredicted(
        surface: StrokeSurface,
        points: [MaskBrushPoint],
        style: StrokeSurfaceStyle,
        generation: UInt64
    ) async throws -> RenderedFrame? {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try await surface.replacePredicted(points: points, style: style, generation: generation) { result in
                        switch result {
                        case .success(let frame):
                            continuation.resume(returning: frame)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
