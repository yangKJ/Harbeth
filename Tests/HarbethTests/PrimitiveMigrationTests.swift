//
//  PrimitiveMigrationTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/1.
//

import CoreGraphics
import Foundation
import Metal
import XCTest
@testable import Harbeth

final class PrimitiveMigrationTests: XCTestCase {
    func testRGBABytesRetainLayoutAlphaAndP3() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let bytes: [UInt8] = [64, 32, 0, 128, 0, 128, 0, 255, 255, 0, 0, 255, 0, 0, 0, 0]
        let source = try RGBA8ImageBuffer(width: 2, height: 2, bytes: bytes, colorSpace: space)
        let image = try source.makeCGImage()
        let restored = try RGBA8ImageBuffer(image)
        XCTAssertEqual(restored.bytes, bytes)
        XCTAssertEqual(restored.colorSpace.name, CGColorSpace.displayP3)
        XCTAssertEqual(image.alphaInfo, .premultipliedLast)
        XCTAssertThrowsError(try RGBA8ImageBuffer(image, maximumPixels: 3))
        XCTAssertThrowsError(try RGBA8ImageBuffer(width: Int.max, height: 2, bytes: [], colorSpace: space))
    }

    func testMigratedPrimitivesUseHarbethErrors() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        XCTAssertThrowsError(try RGBA8ImageBuffer(width: 1, height: 1, bytes: [], colorSpace: space)) { error in
            guard case let HarbethError.renderPrimitiveValidationFailed(primitive, reason) = error else {
                return XCTFail("Expected HarbethError, got \(error)")
            }
            XCTAssertEqual(primitive, "RGBA8ImageBuffer")
            XCTAssertEqual(reason, "invalidImage")
        }
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([0, 0, 0])) { error in
            guard case let HarbethError.renderPrimitiveValidationFailed(primitive, reason) = error else {
                return XCTFail("Expected HarbethError, got \(error)")
            }
            XCTAssertEqual(primitive, "ImageDynamicRangeStatistics")
            XCTAssertEqual(reason, "invalidInputStride")
        }
    }

    func testImageEncodingErrorsKeepStructuredDiagnostics() {
        let errors: [HarbethError] = [.imageDestinationCreationFailed("public.tiff"), .imageEncodingFailed("public.tiff")]
        XCTAssertEqual(errors.map(\.code), [1107, 1108])
        XCTAssertEqual(errors.map(\.harbethDiagnosticCode), ["harbeth.image.destination_create_failed", "harbeth.image.encoding_failed"])
        for error in errors {
            XCTAssertEqual(error.harbethDiagnosticMetadata["format"], "public.tiff")
            XCTAssertEqual((error as NSError).domain, HarbethError.errorDomain)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testImageHasherKeepsEstablishedFNVContract() {
        XCTAssertEqual(ImageContentHasher.hash(""), 0xcbf29ce484222325)
        XCTAssertEqual(ImageContentHasher.hash("a"), 0xaf63dc4c8601ec8c)
        XCTAssertEqual(ImageContentHasher.hash("foobar"), 0x85944171f73967e8)
        var first = ImageContentHasher()
        first.combine(littleEndian: 0x0807060504030201)
        var second = ImageContentHasher()
        for value: UInt8 in 1...8 { second.combine(value) }
        XCTAssertEqual(first.value, second.value)
    }
}

extension PrimitiveMigrationTests {
    func testColorMathRetainsCanonicalAnchorsAndExtendedRangeRoundTrips() {
        let red = RGBColorMath.oklab(SIMD3<Float>(1, 0, 0), space: .sRGB)
        XCTAssertEqual(red.x, 0.6279554, accuracy: 0.00001)
        XCTAssertEqual(red.y, 0.2248631, accuracy: 0.00001)
        XCTAssertEqual(red.z, 0.1258463, accuracy: 0.00001)
        for space in RGBColorSpace.allCases {
            for input in [SIMD3<Float>(0.2, 0.6, 0.9), SIMD3<Float>(-0.1, 1.3, 0.7)] {
                let restored = RGBColorMath.rgb(fromOKLab: RGBColorMath.oklab(input, space: space), space: space)
                for channel in 0..<3 { XCTAssertEqual(restored[channel], input[channel], accuracy: 0.001) }
            }
        }
    }

    func testInverseGridBoundsRetainNonzeroExtentAndAllIntersectingCorners() throws {
        let points = (0..<9).map { CGPoint(x: CGFloat($0 % 3) / 2, y: CGFloat($0 / 3) / 2) }
        let grid = try InverseCoordinateGrid(width: 3, height: 3, points: points)
        let extent = CGRect(x: 10, y: 20, width: 100, height: 80)
        XCTAssertEqual(grid.sourceRegion(for: extent, extent: extent), extent)
        XCTAssertEqual(grid.sourceRegion(for: CGRect(x: 10, y: 60, width: 50, height: 40), extent: extent, padding: 0),
                       CGRect(x: 10, y: 60, width: 50, height: 40))
        XCTAssertEqual(grid.sourceRegion(for: CGRect(x: -100, y: -100, width: 1, height: 1), extent: extent), .zero)
        XCTAssertThrowsError(try InverseCoordinateGrid(width: 3, height: 3, points: []))
        XCTAssertThrowsError(try InverseCoordinateGrid(width: 2, height: 2, points: Array(repeating: CGPoint(x: CGFloat.nan, y: 0), count: 4)))
    }

    func testInverseGridReusesNumericFieldAndInvalidationCreatesNewField() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
        let grid = try InverseCoordinateGrid(width: 2, height: 2, points: points)
        let first = try grid.makeTexture()
        let second = try grid.makeTexture()
        XCTAssertTrue(first === second)
        XCTAssertEqual(first.pixelFormat, .rg32Float)
        HarbethContext.shared.invalidateDerivedResources(domain: .coordinateField)
        let third = try grid.makeTexture()
        XCTAssertFalse(first === third)
    }
}
