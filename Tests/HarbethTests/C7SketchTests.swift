//
//  C7SketchTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/09/12.
//

import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class C7SketchTests: XCTestCase {
    func testUniformImageDoesNotCreateBoundaryLines() async throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        let input = try makeUniformImage(width: 12, height: 10, shade: 128)

        let output = try await HarbethIO<CGImage>(element: input, filter: C7Sketch(edgeStrength: 2)).transmitOutput()
        let pixels = try rgbaBytes(from: output)

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            XCTAssertGreaterThanOrEqual(pixels[offset], 250)
            XCTAssertGreaterThanOrEqual(pixels[offset + 1], 250)
            XCTAssertGreaterThanOrEqual(pixels[offset + 2], 250)
            XCTAssertEqual(pixels[offset + 3], 255)
        }
    }

    private func makeUniformImage(width: Int, height: Int, shade: UInt8) throws -> CGImage {
        var pixels = [UInt8](repeating: shade, count: width * height * 4)
        for offset in stride(from: 3, to: pixels.count, by: 4) {
            pixels[offset] = 255
        }
        return try XCTUnwrap(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        )
    }

    private func rgbaBytes(from image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(
            CGContext(
                data: &pixels,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }
}
