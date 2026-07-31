//
//  SIMDConversionTests.swift
//  Harbeth
//
//  Created by Condy on 2026/7/31.
//

import XCTest
@testable import Harbeth

final class SIMDConversionTests: XCTestCase {

    func testColorSIMDConversionsPreserveRGBAndAlphaSemantics() {
        let color = C7Color(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.4)
        let rgb = color.c7.toSIMD3()
        let rgba = color.c7.toSIMD4()

        XCTAssertEqual(rgb.x, 0.25, accuracy: 0.0001)
        XCTAssertEqual(rgb.y, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rgb.z, 0.75, accuracy: 0.0001)
        XCTAssertEqual(rgba.x, rgb.x, accuracy: 0.0001)
        XCTAssertEqual(rgba.y, rgb.y, accuracy: 0.0001)
        XCTAssertEqual(rgba.z, rgb.z, accuracy: 0.0001)
        XCTAssertEqual(rgba.w, 0.4, accuracy: 0.0001)
    }

    func testPointSIMDConversionsPreserveCoordinateSemantics() {
        XCTAssertEqual(C7Point2D(x: 0.25, y: 0.75).toSIMD2(), SIMD2<Float>(0.25, 0.75))
        XCTAssertEqual(FreePoint2D(x: -0.5, y: 1.5).toSIMD2(), SIMD2<Float>(-0.5, 1.5))
    }
}
