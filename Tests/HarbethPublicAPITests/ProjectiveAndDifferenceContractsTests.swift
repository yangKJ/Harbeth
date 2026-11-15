//
//  ProjectiveAndDifferenceContractsTests.swift
//  HarbethPublicAPITests
//
//  Created by Condy on 2026/11/15.
//

import CoreGraphics
import Harbeth
import XCTest

final class ProjectiveAndDifferenceContractsTests: XCTestCase {
    func testProjectiveCornersAndInverseRoundTrip() throws {
        let points = [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.9, y: 0.1), CGPoint(x: 0.2, y: 0.8), CGPoint(x: 1, y: 1)]
        let transform = try XCTUnwrap(ProjectiveTransform.unitSquare(to: points))
        let inverse = try XCTUnwrap(transform.inverted())
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
        for (source, expected) in zip(corners, points) {
            let actual = try XCTUnwrap(transform.applying(to: source))
            XCTAssertEqual(actual.x, expected.x, accuracy: 1e-10)
            XCTAssertEqual(actual.y, expected.y, accuracy: 1e-10)
        }
        for y in 0...8 {
            for x in 0...8 {
                let source = CGPoint(x: Double(x) / 8, y: Double(y) / 8)
                let result = try XCTUnwrap(inverse.applying(to: XCTUnwrap(transform.applying(to: source))))
                XCTAssertEqual(result.x, source.x, accuracy: 1e-10)
                XCTAssertEqual(result.y, source.y, accuracy: 1e-10)
            }
        }
    }

    func testDegeneracyAndInvalidInputsRemainExplicit() throws {
        XCTAssertNil(ProjectiveTransform.unitSquare(to: []))
        XCTAssertNil(ProjectiveTransform.unitSquare(to: Array(repeating: .zero, count: 4)))
        XCTAssertThrowsError(try ProjectiveTransform(values: [1]))
        XCTAssertThrowsError(try ProjectiveTransform(values: [1, 0, 0, 0, 1, 0, 0, 0, .nan]))
        let singular = try ProjectiveTransform(values: [1, 0, 0, 0, 0, 0, 0, 0, 1])
        XCTAssertNil(singular.inverted())
        let horizon = try ProjectiveTransform(values: [1, 0, 0, 0, 1, 0, 1, 0, -1])
        XCTAssertNil(horizon.applying(to: CGPoint(x: 1, y: 0)))
    }

    func testDifferenceUsesStrictChannelThresholdAndKeepsByteUnits() throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let original = try RGBA8ImageBuffer(
            width: 2,
            height: 1,
            bytes: [0, 0, 0, 255, 0, 0, 0, 255],
            colorSpace: space
        )
        let result = try RGBA8ImageBuffer(
            width: 2,
            height: 1,
            bytes: [8, 0, 0, 255, 9, 0, 0, 255],
            colorSpace: space
        )
        let difference = try ImageDifferenceStatistics.compare(original, result, noticeableChannelDelta: 8)
        XCTAssertEqual(difference.pixelCount, 2)
        XCTAssertEqual(difference.meanChannelDelta, 17.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(difference.noticeablePixelRatio, 0.5)
    }

    func testDifferenceRejectsBrokenBuffersAndDoesNotRedefineAlpha() throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let original = try RGBA8ImageBuffer(
            width: 1,
            height: 1,
            bytes: [0, 0, 0, 0],
            colorSpace: space
        )
        var result = try RGBA8ImageBuffer(
            width: 1,
            height: 1,
            bytes: [0, 0, 0, 255],
            colorSpace: space
        )
        XCTAssertEqual(try ImageDifferenceStatistics.compare(original, result, noticeableChannelDelta: 8).meanChannelDelta, 0)
        XCTAssertThrowsError(try ImageDifferenceStatistics.compare(original, result, noticeableChannelDelta: -1))
        result.bytes.removeLast()
        XCTAssertThrowsError(try ImageDifferenceStatistics.compare(original, result, noticeableChannelDelta: 8))
    }
}
