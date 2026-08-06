//
//  CLAHEPublicAPITests.swift
//  HarbethPublicAPITests
//
//  Created by Condy on 2026/8/5.
//

import Harbeth
import XCTest

final class CLAHEPublicAPITests: XCTestCase {

    func testCLAHEIsPubliclyConstructibleWithGridAndClipLimit() {
        let filter: any C7FilterProtocol = C7CLAHE(
            clipLimit: 3,
            tileGridSize: .init(columns: 6, rows: 4)
        )

        XCTAssertFalse(filter.identifier.isEmpty)
        XCTAssertEqual(filter.factors, [3, 6, 4])
        XCTAssertEqual(filter.kernelPixelContract.globalDependency, .imageStatistics)
    }

    func testMetalCommandAndDestinationContractsArePublic() {
        let filter: any C7MetalCommandEncodingProtocol = C7CLAHE()
        let destination = FilterDestinationTextureContract(
            usage: [.shaderRead, .shaderWrite],
            storageMode: .shared,
            aliasingPolicy: .requiredDistinct
        )

        XCTAssertEqual(filter.modifier, .metalCommand(label: "C7CLAHE"))
        XCTAssertEqual(destination.storageMode, .shared)
        XCTAssertEqual(destination.aliasingPolicy, .requiredDistinct)
    }
}
