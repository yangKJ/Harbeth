//
//  TextureAnalysisReadbackTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/09/04.
//

import XCTest
@testable import Harbeth

final class TextureAnalysisReadbackTests: XCTestCase {
    func testFloat16BitDecodingPreservesFiniteAndSpecialValues() {
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0x3C00), 1, accuracy: .ulpOfOne)
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0xC000), -2, accuracy: .ulpOfOne)
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0x0001), 5.960_464_5e-8, accuracy: .leastNonzeroMagnitude)
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0x7C00), .infinity)
        XCTAssertTrue(TextureAnalysisReadback.float16(bits: 0x7E00).isNaN)
    }
}
