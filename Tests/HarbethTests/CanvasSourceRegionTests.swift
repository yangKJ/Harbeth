//
//  CanvasSourceRegionTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/10/27.
//

import CoreGraphics
import Foundation
import XCTest
@testable import Harbeth

final class CanvasSourceRegionTests: XCTestCase {
    func testFractionalRequestCoversBothEnds() throws {
        let size = CGSize(width: 37, height: 29)
        let pixels = CGRect(x: 3.8, y: 4.6, width: 10.4, height: 7.6)
        let request = CGRect(x: pixels.minX / size.width, y: pixels.minY / size.height,
            width: pixels.width / size.width, height: pixels.height / size.height)
        let result = try XCTUnwrap(CanvasSourceRegion.pixelBounds(for: request, sourceSize: size))
        XCTAssertEqual(result, CGRect(x: 3, y: 4, width: 12, height: 9))
        XCTAssertTrue(result.contains(pixels))
    }

    func testIntegerPixelRequestsRoundTripAcrossNonPowerOfTwoWidths() throws {
        for width in 2...97 {
            for x in 0..<width {
                let request = CGRect(x: CGFloat(x) / CGFloat(width), y: 0,
                    width: 1 / CGFloat(width), height: 1)
                XCTAssertEqual(CanvasSourceRegion.pixelBounds(for: request, sourceSize: CGSize(width: width, height: 29)),
                    CGRect(x: x, y: 0, width: 1, height: 29), "\(width):\(x)")
                let vertical = CGRect(x: 0, y: CGFloat(x) / CGFloat(width), width: 1, height: 1 / CGFloat(width))
                XCTAssertEqual(CanvasSourceRegion.pixelBounds(for: vertical, sourceSize: CGSize(width: 29, height: width)),
                    CGRect(x: 0, y: x, width: 29, height: 1), "纵向 \(width):\(x)")
            }
        }
    }

    func testClippingAndReversedRequestKeepValidSourceBounds() throws {
        let size = CGSize(width: 10, height: 10)
        XCTAssertEqual(CanvasSourceRegion.pixelBounds(for: CGRect(x: -0.2, y: 0.8, width: 0.4, height: 0.4), sourceSize: size),
            CGRect(x: 0, y: 8, width: 2, height: 2))
        XCTAssertEqual(CanvasSourceRegion.pixelBounds(for: CGRect(x: 0.6, y: 0.5, width: -0.2, height: -0.1), sourceSize: size),
            CGRect(x: 4, y: 4, width: 2, height: 1))
        XCTAssertNil(CanvasSourceRegion.pixelBounds(for: CGRect(x: 1, y: 0, width: 0.2, height: 1), sourceSize: size))
        XCTAssertNil(CanvasSourceRegion.pixelBounds(for: .zero, sourceSize: size))
    }

    func testInvalidAndUnboundedInputsAreRejected() {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        for size in [CGSize.zero, CGSize(width: 1.5, height: 1), CGSize(width: CGFloat.infinity, height: 1),
                     CGSize(width: CGFloat(Int32.max) + 1, height: 1)] {
            XCTAssertNil(CanvasSourceRegion.pixelBounds(for: unit, sourceSize: size))
        }
        XCTAssertNil(CanvasSourceRegion.pixelBounds(for: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), sourceSize: CGSize(width: 10, height: 10)))
        XCTAssertNil(CanvasSourceRegion.pixelBounds(for: .infinite, sourceSize: CGSize(width: 10, height: 10)))
    }

    func testTinyRequestStillCoversOnePixelWithoutCrossingExtent() throws {
        let bounds = try XCTUnwrap(CanvasSourceRegion.pixelBounds(
            for: CGRect(x: 0.999999999999999, y: 0.5, width: 0.0000000000000001, height: 0.0000000000000001),
            sourceSize: CGSize(width: 37, height: 29)
        ))
        XCTAssertEqual(bounds.width, 1)
        XCTAssertEqual(bounds.height, 1)
        XCTAssertLessThanOrEqual(bounds.maxX, 37)
        XCTAssertLessThanOrEqual(bounds.maxY, 29)
    }

    func testLargeLogicalExtentDoesNotRequireRasterAllocation() throws {
        let edge = CGFloat(Int32.max)
        let bounds = try XCTUnwrap(CanvasSourceRegion.pixelBounds(
            for: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            sourceSize: CGSize(width: edge, height: edge)
        ))
        XCTAssertGreaterThan(bounds.width, 1)
        XCTAssertLessThanOrEqual(bounds.maxX, edge)
        XCTAssertLessThanOrEqual(bounds.maxY, edge)
    }

    func testActualImageCropIncludesTheLastRequestedRowAndColumn() throws {
        let width = 37
        let height = 29
        var bytes: [UInt8] = []
        bytes.reserveCapacity(width * height * 4)
        for index in 0..<(width * height) {
            bytes.append(contentsOf: [UInt8(index % width * 5), UInt8(index / width * 7), 0, 255])
        }
        let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let request = CGRect(x: 3.8 / 37, y: 4.6 / 29, width: 10.4 / 37, height: 7.6 / 29)
        let bounds = try XCTUnwrap(CanvasSourceRegion.pixelBounds(for: request, sourceSize: CGSize(width: width, height: height)))
        let crop = try XCTUnwrap(image.cropping(to: bounds))
        XCTAssertEqual(crop.width, 12)
        XCTAssertEqual(crop.height, 9)
        let data = try XCTUnwrap(crop.dataProvider?.data as Data?)
        let last = (crop.height - 1) * crop.bytesPerRow + (crop.width - 1) * 4
        XCTAssertEqual(data[last], 14 * 5)
        XCTAssertEqual(data[last + 1], 12 * 7)
    }

    func testActualCropKeepsHalfFloatRangeAndSourceAlpha() throws {
        var bytes: [UInt8] = []
        for index in 0..<(22 * 7) {
            // 1.5、0.125、0.0625、0.25 的 binary16 位型，不依赖 Swift Float16 的架构可用性。
            let components: [UInt16] = index % 22 == 15 ? [0x3E00, 0x3000, 0x2C00, 0x3400] : [0, 0, 0, 0]
            for bits in components {
                bytes.append(UInt8(bits & 255))
                bytes.append(UInt8(bits >> 8))
            }
        }
        let info = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder16Little.rawValue
            | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        let image = try XCTUnwrap(CGImage(width: 22, height: 7, bitsPerComponent: 16, bitsPerPixel: 64,
            bytesPerRow: 22 * 8, space: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, bitmapInfo: info,
            provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let bounds = try XCTUnwrap(CanvasSourceRegion.pixelBounds(
            for: CGRect(x: 15.0 / 22, y: 2.0 / 7, width: 1.0 / 22, height: 1.0 / 7),
            sourceSize: CGSize(width: 22, height: 7)
        ))
        let crop = try XCTUnwrap(image.cropping(to: bounds))
        XCTAssertEqual(crop.width, 1)
        XCTAssertEqual(crop.height, 1)
        XCTAssertEqual(crop.bitsPerComponent, 16)
        XCTAssertTrue(crop.bitmapInfo.contains(.floatComponents))
        let data = try XCTUnwrap(crop.dataProvider?.data as Data?)
        let red = UInt16(data[0]) | UInt16(data[1]) << 8
        let alpha = UInt16(data[6]) | UInt16(data[7]) << 8
        XCTAssertEqual(red, 0x3E00)
        XCTAssertEqual(alpha, 0x3400)
    }
}
