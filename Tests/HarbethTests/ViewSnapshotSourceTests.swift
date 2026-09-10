//
//  ViewSnapshotSourceTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/9/7.
//

#if os(iOS) || os(tvOS)
import UIKit
import XCTest
@testable import Harbeth

@MainActor
final class ViewSnapshotSourceTests: XCTestCase {

    func testCapturePublishesMonotonicImmutableRevisions() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 16))
        view.backgroundColor = .red
        let source = ViewSnapshotSource(view: view)

        let first = try source.capture()
        view.backgroundColor = .blue
        let second = try source.capture()

        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(second.revision, 2)
        XCTAssertTrue(source.latestSnapshot === second)
        XCTAssertEqual(first.pixelSize, C7Size(width: 32, height: 16))
    }

    func testSnapshotUploadsOnceAndProvidesBothCompositionRoutes() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        view.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        let snapshot = try ViewSnapshotSource(view: view).capture()

        let firstTexture = try snapshot.texture()
        let secondTexture = try snapshot.texture()
        let source = try snapshot.imageSource()
        let primitive = try snapshot.makeRenderLayerComposite(opacity: 0.75)
        let layer = try snapshot.makeImageLayer()

        XCTAssertTrue(firstTexture === secondTexture)
        XCTAssertEqual(source.kindName, "texture")
        XCTAssertTrue(primitive.layerTexture === firstTexture)
        XCTAssertTrue(try layer.content.makeTexture() === firstTexture)
    }

    func testBezierSnapshotDoesNotMutateViewLayerMask() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        let originalMask = CALayer()
        view.layer.mask = originalMask

        _ = view.c7.toImage(bezierPath: UIBezierPath(ovalIn: view.bounds))

        XCTAssertTrue(view.layer.mask === originalMask)
    }
}
#elseif os(macOS)
import AppKit
import XCTest
@testable import Harbeth

@MainActor
final class ViewSnapshotSourceTests: XCTestCase {

    func testLayerCapturePublishesMonotonicRevisions() throws {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 32, height: 16)
        layer.contentsScale = 1
        layer.backgroundColor = NSColor.red.cgColor
        let source = ViewSnapshotSource(layer: layer)

        let first = try source.capture()
        layer.backgroundColor = NSColor.blue.cgColor
        let second = try source.capture()

        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(second.revision, 2)
        XCTAssertTrue(source.latestSnapshot === second)
        XCTAssertEqual(first.pixelSize, C7Size(width: 32, height: 16))
    }

    func testEmptyLayerReportsHarbethError() {
        let source = ViewSnapshotSource(layer: CALayer())

        XCTAssertThrowsError(try source.capture()) { error in
            guard case HarbethError.viewSnapshotCaptureFailed(let reason) = error else {
                return XCTFail("Expected HarbethError.viewSnapshotCaptureFailed, got \(error)")
            }
            XCTAssertEqual(reason, "Layer bounds must be non-empty")
        }
    }

    func testLayerSnapshotUploadsOnceAndProvidesBothCompositionRoutes() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
        layer.contentsScale = 1
        layer.backgroundColor = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.5).cgColor
        let snapshot = try ViewSnapshotSource(layer: layer).capture()

        let firstTexture = try snapshot.texture()
        let secondTexture = try snapshot.texture()
        let source = try snapshot.imageSource()
        let primitive = try snapshot.makeRenderLayerComposite(opacity: 0.75)
        let imageLayer = try snapshot.makeImageLayer()

        XCTAssertTrue(firstTexture === secondTexture)
        XCTAssertEqual(source.kindName, "texture")
        XCTAssertTrue(primitive.layerTexture === firstTexture)
        XCTAssertTrue(try imageLayer.content.makeTexture() === firstTexture)
    }

    func testCapturedTransparentLayerCompositesWithPremultipliedSourceOver() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        layer.contentsScale = 1
        layer.backgroundColor = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.5).cgColor
        let snapshot = try ViewSnapshotSource(layer: layer).capture()
        let background = try MaskTestHelpers.makeSolidTexture(
            red: 0,
            green: 0,
            blue: 255,
            alpha: 255
        )
        let snapshotBytes = try XCTUnwrap(snapshot.texture().c7.bytes())

        let output: MTLTexture = try HarbethIO(
            element: background,
            filter: snapshot.makeRenderLayerComposite()
        ).output()
        let bytes = try XCTUnwrap(output.c7.bytes())

        XCTAssertGreaterThan(snapshotBytes[0], 100)
        XCTAssertEqual(snapshotBytes[3], 128, accuracy: 8)
        XCTAssertGreaterThan(bytes[0], 100)
        XCTAssertLessThan(bytes[2], 200)
        XCTAssertEqual(bytes[3], 255, accuracy: 2)
    }
}
#endif
