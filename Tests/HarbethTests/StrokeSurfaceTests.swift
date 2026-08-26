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
        let predicted = try await surface.replacePredicted(
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

        _ = try await surface.replacePredicted(
            points: [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))],
            style: style,
            generation: 4
        )

        do {
            _ = try await surface.replacePredicted(points: [], style: style, generation: 3)
            XCTFail("Expected stale predicted generation to be rejected")
        } catch {
            XCTAssertEqual(
                error as? StrokeSurfaceError,
                .stalePredictedGeneration(requested: 3, current: 4)
            )
        }
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
}
