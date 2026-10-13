//
//  MaskCappedAddTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/10/13.
//

import XCTest
@testable import Harbeth

final class MaskCappedAddTests: XCTestCase {
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
