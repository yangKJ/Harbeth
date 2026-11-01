// Created by Condy on 2026/09/18.
import XCTest
@testable import Harbeth

final class HalfFloatConversionTests: XCTestCase {
    func testRoundTripPreservesTextureScalarLayoutAndSpecialValues() throws {
        let bits: [UInt16] = [0, 0x8000, 0x3c00, 0xc000, 1, 0x7c00, 0xfc00, 0x7e00]
        let values = try HalfFloatConversion.decode(bits)
        XCTAssertEqual(values[1].sign, .minus)
        XCTAssertEqual(values[2], 1)
        XCTAssertEqual(values[3], -2)
        XCTAssertEqual(values[4], Float(pow(2.0, -24)))
        XCTAssertEqual(values[5], .infinity)
        XCTAssertEqual(values[6], -.infinity)
        XCTAssertTrue(values[7].isNaN)
        XCTAssertEqual(try HalfFloatConversion.encode(Array(values.prefix(7))), Array(bits.prefix(7)))
    }

    func testEmptyPlanesRemainEmpty() throws {
        XCTAssertTrue(try HalfFloatConversion.decode([]).isEmpty)
        XCTAssertTrue(try HalfFloatConversion.encode([]).isEmpty)
    }

    func testEveryHalfBitPatternMatchesNativePromotion() throws {
        #if arch(arm64)
        let bits = (0...65_535).map { UInt16($0) }
        let decoded = try HalfFloatConversion.decode(bits)
        for index in bits.indices {
            let expected = Float(Float16(bitPattern: bits[index]))
            if expected.isNaN {
                XCTAssertTrue(decoded[index].isNaN)
            } else {
                XCTAssertEqual(decoded[index].bitPattern, expected.bitPattern)
            }
        }
        #else
        throw XCTSkip("原生 Float16 对照仅在 arm64 执行")
        #endif
    }
}
