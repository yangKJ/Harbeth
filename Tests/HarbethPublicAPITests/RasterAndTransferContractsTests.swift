//
//  RasterAndTransferContractsTests.swift
//  HarbethPublicAPITests
//
//  Created by Condy on 2026/11/15.
//

import CoreGraphics
import Foundation
import Harbeth
import XCTest

final class RasterAndTransferContractsTests: XCTestCase {
    func testSDRPlanPreservesRGBSpaceAndPremultipliedAlpha() throws {
        for name in [CGColorSpace.sRGB, CGColorSpace.displayP3] {
            let space = try XCTUnwrap(CGColorSpace(name: name))
            let source = try image(space: space, bits: 8)
            let plan = ImageRasterPlan(cgImage: source)
            XCTAssertFalse(plan.isHighPrecision)
            XCTAssertFalse(ImageRasterPlan.requiresHighPrecision(source))
            XCTAssertEqual(plan.colorSpace.name, space.name)
            let context = try XCTUnwrap(plan.makeContext(width: 2, height: 1))
            XCTAssertEqual(context.bitsPerComponent, 8)
            XCTAssertEqual(context.alphaInfo, .premultipliedLast)
            XCTAssertEqual(context.bytesPerRow, 8)
        }
    }

    func testHalfFloatPlanDoesNotClampExtendedRangeOrDropAlpha() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let source = try image(space: space, bits: 16)
        let plan = ImageRasterPlan(cgImage: source)
        XCTAssertTrue(plan.isHighPrecision)
        XCTAssertTrue(ImageRasterPlan.requiresHighPrecision(source))
        let context = try XCTUnwrap(plan.makeContext(width: 2, height: 1))
        context.draw(source, in: CGRect(x: 0, y: 0, width: 2, height: 1))
        XCTAssertEqual(context.bitsPerComponent, 16)
        XCTAssertEqual(context.alphaInfo, .premultipliedLast)
        let output = try XCTUnwrap(context.makeImage())
        let bytes = [UInt8](try XCTUnwrap(output.dataProvider?.data) as Data)
        let red = Float(Float16(bitPattern: UInt16(bytes[0]) | UInt16(bytes[1]) << 8))
        let alpha = Float(Float16(bitPattern: UInt16(bytes[6]) | UInt16(bytes[7]) << 8))
        XCTAssertEqual(red, 1, accuracy: 0.002)
        XCTAssertEqual(alpha, 0.5, accuracy: 0.002)
    }

    func testNonRGBUsesSRGBAndRejectsInvalidAllocationDimensions() throws {
        let bytes = Data([128, 255])
        let source = try XCTUnwrap(CGImage(
            width: 2, height: 1, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 2,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: try XCTUnwrap(CGDataProvider(data: bytes as CFData)), decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        ))
        let plan = ImageRasterPlan(cgImage: source)
        XCTAssertEqual(plan.colorSpace.name, CGColorSpace.sRGB)
        XCTAssertNil(plan.makeContext(width: 0, height: 1))
        XCTAssertNil(plan.makeContext(width: Int.max, height: 2))
        XCTAssertNil(plan.makeContext(width: 2, height: Int.max))
    }

    func testTransferResolverKeepsP3MetadataDistinctFromModeDefaults() throws {
        let decoded = try XCTUnwrap(C7RGBTransferConversion(from: .displayP3, to: .extendedLinearDisplayP3))
        XCTAssertEqual(decoded.mode, .sRGBToLinear)
        XCTAssertEqual(decoded.kernelPixelContract.inputColorSpace.gamut, .displayP3)
        let legacyMode = C7RGBTransferConversion(mode: decoded.mode)
        XCTAssertEqual(legacyMode.kernelPixelContract.inputColorSpace.gamut, .sRGB)
        XCTAssertNotEqual(decoded.kernelPixelContract, legacyMode.kernelPixelContract)
        XCTAssertNil(C7RGBTransferConversion(from: .preserveInput, to: .extendedLinearDisplayP3))
    }

    func testTransferResolverRetainsPQAndHLGModes() throws {
        let linear = ImageColorSpaceContract(name: "linear-2020", preservesInput: false, gamut: .ituR2020, transferFunction: .linear)
        XCTAssertEqual(C7RGBTransferConversion(from: .hdrPQ, to: linear)?.mode, .pqToLinear)
        XCTAssertEqual(C7RGBTransferConversion(from: linear, to: .hdrPQ)?.mode, .linearToPQ)
        XCTAssertEqual(C7RGBTransferConversion(from: .hdrHLG, to: linear)?.mode, .hlgToLinear)
        XCTAssertEqual(C7RGBTransferConversion(from: linear, to: .hdrHLG)?.mode, .linearToHLG)
    }

    private func image(space: CGColorSpace, bits: Int) throws -> CGImage {
        let info = bits == 16
            ? CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            : CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 2, height: 1, bitsPerComponent: bits, bytesPerRow: bits == 16 ? 16 : 8,
            space: space, bitmapInfo: info
        ))
        context.setFillColor(try XCTUnwrap(CGColor(colorSpace: space, components: [2, 0.5, 0.25, 0.5])))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 1))
        return try XCTUnwrap(context.makeImage())
    }
}
