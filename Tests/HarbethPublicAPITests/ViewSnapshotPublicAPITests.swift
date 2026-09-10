//
//  ViewSnapshotPublicAPITests.swift
//  HarbethPublicAPITests
//
//  Created by Condy on 2026/9/7.
//

#if os(macOS)
import QuartzCore
import XCTest
import Harbeth

@MainActor
final class ViewSnapshotPublicAPITests: XCTestCase {

    func testLayerSnapshotSurfaceCompilesOutsideImplementationModule() throws {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
        let source = ViewSnapshotSource(layer: layer, identifier: "public-api")
        let snapshot = try source.capture()

        XCTAssertEqual(snapshot.revision, 1)
        XCTAssertEqual(snapshot.captureMode, .layer)
        XCTAssertEqual(snapshot.pixelSize, C7Size(width: 8, height: 8))
        XCTAssertEqual(try snapshot.imageSource().kindName, "texture")
    }
}
#endif
