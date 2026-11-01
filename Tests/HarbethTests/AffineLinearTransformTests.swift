//
//  AffineLinearTransformTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/10/13.
//

import CoreGraphics
import Foundation
import XCTest
@testable import Harbeth

final class AffineLinearTransformTests: XCTestCase {
    func testCombinedRotationScaleShearAndInverseRecoverPoint() throws {
        let rotation = try AffineLinearTransform(CGAffineTransform(rotationAngle: 0.37))
        let scale = try AffineLinearTransform(CGAffineTransform(scaleX: 1.7, y: 0.65))
        let shear = try AffineLinearTransform(CGAffineTransform(a: 1, b: 0.21, c: -0.34, d: 1, tx: 0, ty: 0))
        let combined = try rotation.concatenating(scale).concatenating(shear)
        let inverse = try combined.inverted()
        let point = CGPoint(x: 12.5, y: -4.25)
        let transformed = point.applying(combined.cgAffineTransform)
        let restored = transformed.applying(inverse.cgAffineTransform)
        XCTAssertEqual(restored.x, point.x, accuracy: 1e-9)
        XCTAssertEqual(restored.y, point.y, accuracy: 1e-9)
    }

    func testMirrorWithNegativeDeterminantRemainsInvertible() throws {
        let mirror = try AffineLinearTransform(CGAffineTransform(scaleX: -1, y: 1))
        XCTAssertLessThan(mirror.a * mirror.d - mirror.b * mirror.c, 0)
        let point = CGPoint(x: 3, y: 8)
        let restored = point.applying(mirror.cgAffineTransform).applying(try mirror.inverted().cgAffineTransform)
        XCTAssertEqual(restored.x, point.x, accuracy: 1e-9)
        XCTAssertEqual(restored.y, point.y, accuracy: 1e-9)
    }

    func testSingularNonFiniteAndTranslatedCGAffineValuesReject() {
        XCTAssertThrowsError(try AffineLinearTransform(a: 1, b: 0, c: 0, d: 0))
        XCTAssertThrowsError(try AffineLinearTransform(a: .nan, b: 0, c: 0, d: 1))
        XCTAssertThrowsError(try AffineLinearTransform(CGAffineTransform(translationX: 1, y: 2)))
    }

    func testJSONAndPropertyListRoundTrip() throws {
        let value = try AffineLinearTransform(a: 1.25, b: -0.2, c: 0.45, d: 0.9)
        let json = try JSONDecoder().decode(AffineLinearTransform.self, from: JSONEncoder().encode(value))
        let plist = try PropertyListDecoder().decode(AffineLinearTransform.self, from: PropertyListEncoder().encode(value))
        XCTAssertEqual(json, value)
        XCTAssertEqual(plist, value)
    }

    func testMalformedDecodingRejectsMissingSingularAndNonFiniteValues() throws {
        let missing = Data(#"{"a":1,"b":0,"c":0}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AffineLinearTransform.self, from: missing))
        let singular = Data(#"{"a":1,"b":0,"c":0,"d":0}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AffineLinearTransform.self, from: singular))
        let nonFinite = Data(#"{"a":1e999,"b":0,"c":0,"d":1}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AffineLinearTransform.self, from: nonFinite))
    }

    func testConcatenationOrderIsNonCommutative() throws {
        let scale = try AffineLinearTransform(CGAffineTransform(scaleX: 2, y: 1))
        let shear = try AffineLinearTransform(CGAffineTransform(a: 1, b: 0, c: 0.5, d: 1, tx: 0, ty: 0))
        let scaleThenShear = try scale.concatenating(shear)
        let shearThenScale = try shear.concatenating(scale)
        let point = CGPoint(x: 4, y: 3)
        let first = point.applying(scaleThenShear.cgAffineTransform)
        let second = point.applying(shearThenScale.cgAffineTransform)
        XCTAssertNotEqual(first.x, second.x, accuracy: 1e-9)
        XCTAssertEqual(first.y, second.y, accuracy: 1e-9)
    }
}
