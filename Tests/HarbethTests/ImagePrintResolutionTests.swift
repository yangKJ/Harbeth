//
//  ImagePrintResolutionTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/1.
//

import Foundation
import XCTest
@testable import Harbeth

final class ImagePrintResolutionTests: XCTestCase {
    func testFinitePositiveCodableResolution() throws {
        let value = try XCTUnwrap(ImagePrintResolution(horizontalDPI: 300, verticalDPI: 150))
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(ImagePrintResolution.self, from: data), value)
        XCTAssertNil(ImagePrintResolution(horizontalDPI: 0, verticalDPI: 150))
        XCTAssertNil(ImagePrintResolution(horizontalDPI: .infinity, verticalDPI: 150))
        XCTAssertThrowsError(try JSONDecoder().decode(ImagePrintResolution.self, from: Data(#"{"horizontalDPI":0,"verticalDPI":1}"#.utf8)))
    }
}
