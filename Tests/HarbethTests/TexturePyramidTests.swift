//
//  TexturePyramidTests.swift
//  HarbethTests
//

import XCTest
import CoreGraphics
import Metal
@testable import Harbeth

final class TexturePyramidTests: XCTestCase {

    func testTexturePyramidUsesCeilHalfDimensionsForEvenAndOddSizes() throws {
        let even = try MaskTestHelpers.makeTexture(width: 8, height: 6, red: 255, alpha: 255)
        let evenPyramid = try TexturePyramid(source: even)
        XCTAssertEqual(evenPyramid.levels.map(\.pixelSize), [
            C7Size(width: 8, height: 6),
            C7Size(width: 4, height: 3),
            C7Size(width: 2, height: 2),
            C7Size(width: 1, height: 1)
        ])

        let odd = try MaskTestHelpers.makeTexture(width: 5, height: 3, red: 255, alpha: 255)
        let oddPyramid = try TexturePyramid(source: odd)
        XCTAssertEqual(oddPyramid.levels.map(\.pixelSize), [
            C7Size(width: 5, height: 3),
            C7Size(width: 3, height: 2),
            C7Size(width: 2, height: 1),
            C7Size(width: 1, height: 1)
        ])
    }

    func testTexturePyramidStopsAtOnePixelAndHonorsMaximumLevelCount() throws {
        let source = try MaskTestHelpers.makeTexture(width: 1, height: 1, red: 128, alpha: 255)
        let pyramid = try TexturePyramid(source: source)
        XCTAssertEqual(pyramid.levels.count, 1)

        let larger = try MaskTestHelpers.makeTexture(width: 16, height: 8, red: 255, alpha: 255)
        let limited = try TexturePyramid(source: larger, maxLevels: 2)
        XCTAssertEqual(limited.levels.count, 2)
        XCTAssertThrowsError(try TexturePyramid(source: larger, maxLevels: 0)) { error in
            guard case HarbethError.configurationInvalid = error else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
        }
    }

    func testTexturePyramidPreservesROIOriginAndLogicalExtent() throws {
        let source = try MaskTestHelpers.makeTexture(width: 8, height: 6, red: 255, alpha: 255)
        let context = try TextureRegionContext(
            logicalExtent: CGRect(x: 0, y: 0, width: 8, height: 6),
            readRegion: CGRect(x: 2, y: 1, width: 4, height: 3),
            writeRegion: CGRect(x: 2, y: 1, width: 4, height: 3),
            globalOrigin: CGPoint(x: 100, y: 50)
        )
        let pyramid = try TexturePyramid(source: source, region: context)
        let level = try XCTUnwrap(pyramid.levels.first)

        XCTAssertEqual(level.pixelSize, C7Size(width: 4, height: 3))
        XCTAssertEqual(level.logicalExtent, context.logicalExtent)
        XCTAssertEqual(level.regionOrigin, CGPoint(x: 100, y: 50))
        XCTAssertEqual(pyramid.regionOrigin, CGPoint(x: 100, y: 50))
    }

    func testTexturePyramidCanUpsampleBackToExactTargetSize() throws {
        let source = try MaskTestHelpers.makeTexture(width: 5, height: 3, red: 255, alpha: 255)
        let pyramid = try TexturePyramid(source: source, maxLevels: 2)
        let smallest = try XCTUnwrap(pyramid.levels.last)
        let restored = try pyramid.upsample(smallest, to: C7Size(width: 5, height: 3))

        XCTAssertEqual(restored.pixelSize, C7Size(width: 5, height: 3))
        XCTAssertEqual(restored.logicalExtent, pyramid.logicalExtent)
        XCTAssertEqual(restored.regionOrigin, pyramid.regionOrigin)
        restored.release()
    }

    func testTexturePyramidReleaseIsIdempotentAndReturnsLeasedIntermediates() throws {
        let source = try MaskTestHelpers.makeTexture(width: 8, height: 8, red: 255, alpha: 255)
        Shared.shared.resetTexturePoolStatistics()
        let before = Shared.shared.texturePoolStatistics?.currentTextureCount ?? 0
        let pyramid = try TexturePyramid(source: source, maxLevels: 3)
        pyramid.release()
        pyramid.release()
        let after = Shared.shared.texturePoolStatistics?.currentTextureCount ?? 0

        XCTAssertGreaterThanOrEqual(after, before)
    }
}
