//
//  MaskCappedAddTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/10/13.
//

import XCTest
@testable import Harbeth

final class MaskCappedAddTests: XCTestCase {
    func testGPUFlowAccumulatesWithinOneBacktrackingStrokeAndLegacyDoesNot() throws {
        _ = try MaskTestHelpers.requireDevice()
        let first = MaskBrushPoint(point: CGPoint(x: 0.2, y: 0.5), pressure: 1)
        let last = MaskBrushPoint(point: CGPoint(x: 0.8, y: 0.5), pressure: 1)
        func center(_ points: [MaskBrushPoint], accumulated: Bool) throws -> Float {
            let recipe = MaskBrushRecipe(size: C7Size(width: 64, height: 64), points: points,
                settings: .init(width: 0.2, hardness: 1, spacing: 0.5, smoothing: 0, flow: 0.12, accumulatesFlow: accumulated), storageFormat: .rgba8)
            let texture = try recipe.makeTexture()
            let bytes = try XCTUnwrap(texture.c7.bytes())
            return Float(bytes[(32 * 64 + 32) * 4]) / 255
        }
        let single = try center([first, last], accumulated: true)
        let repeated = try center([first, last, first, last], accumulated: true)
        XCTAssertGreaterThan(repeated, single + 0.15)
        XCTAssertLessThan(repeated, 0.9)
        XCTAssertEqual(try center([first, last], accumulated: false),
            try center([first, last, first, last], accumulated: false), accuracy: 0.008)
        let legacyJSON = "{\"width\":0.2,\"hardness\":1,\"spacing\":0.5,\"smoothing\":0,\"flow\":0.12,\"density\":1,\"mode\":\"paint\"}"
        XCTAssertFalse(try JSONDecoder().decode(MaskBrushSettings.self, from: Data(legacyJSON.utf8)).accumulatesFlow)
    }

    func testGPUAccumulatedFlowKeepsPhaseAcrossRegionRebasing() throws {
        _ = try MaskTestHelpers.requireDevice()
        let settings = MaskBrushSettings(width: 0.2, hardness: 0.6, spacing: 0.3, smoothing: 0, flow: 0.15, accumulatesFlow: true)
        let recipe = MaskBrushRecipe(size: C7Size(width: 256, height: 128), points: [
            .init(point: CGPoint(x: 0.05, y: 0.5)), .init(point: CGPoint(x: 0.95, y: 0.5))
        ], settings: settings, storageFormat: .rgba8)
        let full = try MaskTestHelpers.bytes(in: recipe.makeTexture())
        for tileIndex in 0..<2 {
            let points = recipe.preparedPoints.map {
                MaskBrushPoint(point: CGPoint(x: $0.point.x * 2 - CGFloat(tileIndex), y: $0.point.y), pressure: $0.pressure)
            }
            let tile = MaskBrushRecipe(size: C7Size(width: 128, height: 128), preparedPoints: points,
                settings: settings, storageFormat: .rgba8)
            let bytes = try MaskTestHelpers.bytes(in: tile.makeTexture())
            for y in 0..<128 {
                for x in 0..<128 {
                    XCTAssertEqual(Int(bytes[(y * 128 + x) * 4]), Int(full[(y * 256 + x + tileIndex * 128) * 4]), accuracy: 1)
                }
            }
        }
    }

    func testRepeatedPaintDoesNotExceedDensityCap() {
        let first = MaskMath.cappedAddCoverage(existing: 0, brushCoverage: 1, cap: 0.4)
        let second = MaskMath.cappedAddCoverage(existing: first, brushCoverage: 1, cap: 0.4)

        XCTAssertEqual(first, 0.4, accuracy: 0.0001)
        XCTAssertEqual(second, 0.4, accuracy: 0.0001)
    }

    func testCoverageAboveCapIsPreserved() {
        XCTAssertEqual(
            MaskMath.cappedAddCoverage(existing: 0.7, brushCoverage: 1, cap: 0.4),
            0.7,
            accuracy: 0.0001
        )
    }

    func testHigherDensityCanContinueIncreasingCoverage() {
        let low = MaskMath.cappedAddCoverage(existing: 0, brushCoverage: 1, cap: 0.4)
        let high = MaskMath.cappedAddCoverage(existing: low, brushCoverage: 1, cap: 0.8)

        XCTAssertEqual(low, 0.4, accuracy: 0.0001)
        XCTAssertEqual(high, 0.8, accuracy: 0.0001)
    }

    func testGPURepeatedCoverageUsesCapAcrossBatchBoundaries() throws {
        _ = try MaskTestHelpers.requireDevice()
        let empty = try MaskTestHelpers.makeTexture(width: 2, height: 2, red: 0, alpha: 255)
        let coverage = try MaskTestHelpers.makeTexture(width: 2, height: 2, red: 64, alpha: 255)
        let base = MaskDescriptor(texture: empty, component: .red)
        let brush = MaskDescriptor(texture: coverage, component: .red, opacity: 0.4)
        let steps = (0..<5).map { MaskCompositeStep.cappedAdd(brush, name: "stroke-\($0)") }
        let texture = try MaskCompositeRecipe(baseMask: base, steps: steps).makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)
        var expected: Float = 0
        let coverageValue: Float = 64.0 / 255.0
        for _ in 0..<5 { expected += max(Float(0.4) - expected, 0) * coverageValue }
        XCTAssertEqual(Float(bytes[0]) / 255, expected, accuracy: 0.012)
        XCTAssertLessThanOrEqual(Float(bytes[0]) / 255, 0.4)
    }

    func testGPULegacyAdditionAndEraseKeepTheirExistingMeaning() throws {
        _ = try MaskTestHelpers.requireDevice()
        let empty = try MaskTestHelpers.makeTexture(width: 2, height: 2, red: 0, alpha: 255)
        let coverage = try MaskTestHelpers.makeTexture(width: 2, height: 2, red: 255, alpha: 255)
        let brush = MaskDescriptor(texture: coverage, component: .red, opacity: 0.4)
        let legacy = MaskCompositeRecipe(baseMask: MaskDescriptor(texture: empty, component: .red))
            .adding(brush).adding(brush)
        let beforeErase = try MaskTestHelpers.bytes(in: legacy.makeTexture())
        XCTAssertEqual(Float(beforeErase[0]) / 255, 0.8, accuracy: 0.012)
        let eraser = MaskDescriptor(texture: coverage, component: .red, opacity: 0.25)
        let erased = try MaskTestHelpers.bytes(in: legacy.subtracting(eraser).makeTexture())
        XCTAssertEqual(Float(erased[0]) / 255, 0.6, accuracy: 0.012)
    }
}
