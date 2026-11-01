//
//  PrimitiveMigrationTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/1.
//

import CoreGraphics
import Foundation
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
