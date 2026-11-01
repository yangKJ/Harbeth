//
//  ImageTIFF16EncoderTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/1.
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import XCTest
@testable import Harbeth

final class ImageTIFF16EncoderTests: XCTestCase {
    func testTIFF16EncodingWritesRealSixteenBitPixels() throws {
        let source = try makeImage(width: 12, height: 7)
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let half = try XCTUnwrap(CIContext().createCGImage(
            CIImage(cgImage: source), from: CGRect(x: 0, y: 0, width: 12, height: 7),
            format: .RGBAh, colorSpace: colorSpace, deferred: false
        ))
        XCTAssertTrue(half.bitmapInfo.contains(.floatComponents))
        let data = try ImageTIFF16Encoder.encode(CIImage(cgImage: half), colorSpace: colorSpace)
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        )
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))

        XCTAssertEqual(CGImageSourceGetType(imageSource) as String?, "public.tiff")
        XCTAssertEqual(properties[kCGImagePropertyDepth] as? Int, 16)
        XCTAssertFalse(properties[kCGImagePropertyIsFloat] as? Bool ?? false)
        XCTAssertEqual(decoded.bitsPerComponent, 16)
        XCTAssertEqual(decoded.width, 12)
        XCTAssertEqual(decoded.height, 7)
        let expected = try rgbaBytes(for: source)
        let actual = try rgbaBytes(for: decoded)
        XCTAssertEqual(actual.count, expected.count)
        XCTAssertLessThanOrEqual(zip(actual, expected).map { abs(Int($0) - Int($1)) }.max() ?? 0, 1)
    }

    func testTIFF16FileEncodingKeepsIntegerSamplesAndPrintDensity() throws {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        var samples: [UInt16] = []
        for index in 0..<(12 * 7) {
            samples.append(contentsOf: [UInt16(8000 + index * 17), 16000, 24000, 65535])
        }
        let pixels = samples.withUnsafeBytes { Data($0) }
        let provider = try XCTUnwrap(CGDataProvider(data: pixels as CFData))
        let image = try XCTUnwrap(CGImage(
            width: 12, height: 7, bitsPerComponent: 16, bitsPerPixel: 64,
            bytesPerRow: 12 * 8, space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder16Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        defer { try? FileManager.default.removeItem(at: url) }

        try ImageTIFF16Encoder.write(image, to: url,
            printResolution: ImagePrintResolution(horizontalDPI: 144, verticalDPI: 288))

        let encoded = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(encoded, 0, nil) as? [CFString: Any])
        let tiff = try XCTUnwrap(properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(encoded, 0, nil))
        XCTAssertEqual(properties[kCGImagePropertyDepth] as? Int, 16)
        XCTAssertFalse(properties[kCGImagePropertyIsFloat] as? Bool ?? false)
        XCTAssertEqual(properties[kCGImagePropertyDPIWidth] as? Double, 144)
        XCTAssertEqual(properties[kCGImagePropertyDPIHeight] as? Double, 288)
        XCTAssertEqual(tiff[kCGImagePropertyTIFFCompression] as? Int, 1)
        XCTAssertEqual(decoded.width, 12)
        XCTAssertEqual(decoded.height, 7)
        XCTAssertEqual(decoded.colorSpace?.name, CGColorSpace.displayP3)
        XCTAssertEqual(try rgbaBytes(for: decoded), try rgbaBytes(for: image))
    }

    func testTIFF16FileRejectsFloatSamplesBeforeTouchingDestination() throws {
        let source = try makeImage(width: 12, height: 7)
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let half = try XCTUnwrap(CIContext().createCGImage(
            CIImage(cgImage: source), from: CGRect(x: 0, y: 0, width: 12, height: 7),
            format: .RGBAh, colorSpace: colorSpace, deferred: false
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("已有文件".utf8)
        try original.write(to: url)

        XCTAssertThrowsError(try ImageTIFF16Encoder.write(half, to: url)) { error in
            guard case let HarbethError.renderPrimitiveValidationFailed(primitive, reason) = error else {
                return XCTFail("Expected HarbethError, got \(error)")
            }
            XCTAssertEqual(primitive, "ImageTIFF16Encoder")
            XCTAssertEqual(reason, "integerRGBA16Required")
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    private func makeImage(width: Int, height: Int) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let optionalContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let context = try XCTUnwrap(optionalContext)
        context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.4))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    private func rgbaBytes(for image: CGImage) throws -> Data {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let bytesPerRow = image.width * 4
        var data = Data(count: bytesPerRow * image.height)
        let rendered = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(rendered)
        return data
    }
}
