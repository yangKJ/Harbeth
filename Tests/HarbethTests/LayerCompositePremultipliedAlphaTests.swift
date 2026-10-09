//
//  LayerCompositePremultipliedAlphaTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/10/9.
//

import CoreGraphics
import XCTest
@testable import Harbeth

final class LayerCompositePremultipliedAlphaTests: XCTestCase {
    func testPremultipliedForegroundIsNotMultipliedByAlphaAgain() throws {
        let pixel = try composite(background: [40, 80, 120, 255], foreground: [128, 0, 0, 128], opacity: 1)
        assertPixel(pixel, expected: [148, 40, 60, 255])
    }

    func testTransparentBackgroundRetainsPremultipliedColorAndCombinedAlpha() throws {
        let pixel = try composite(background: [0, 64, 0, 128], foreground: [128, 0, 0, 128], opacity: 1)
        assertPixel(pixel, expected: [128, 32, 0, 192])
    }

    func testOpacityChangesCoverageOnce() throws {
        let pixel = try composite(background: [40, 80, 120, 255], foreground: [128, 0, 0, 128], opacity: 0.25)
        assertPixel(pixel, expected: [67, 70, 105, 255])
    }

    func testSoftLightUsesLighteningBranchAndLowBackdropPolynomial() throws {
        let pixel = try composite(background: [32, 32, 32, 255], foreground: [96, 96, 96, 128], opacity: 1, mode: .softLight)
        // 独立按 W3C/Photoshop 的 D(B) 分段公式计算，避免把同一 shader 当期望值。
        let backdrop = 32.0 / 255
        let source = 96.0 / 128
        let lifted = ((16 * backdrop - 12) * backdrop + 4) * backdrop
        let blended = backdrop + (2 * source - 1) * (lifted - backdrop)
        let expected = (backdrop * (1 - 128.0 / 255) + blended * (128.0 / 255)) * 255
        XCTAssertEqual(Double(pixel[0]), expected, accuracy: 2)
        XCTAssertGreaterThan(pixel[0], 32)
    }

    private func composite(background: [UInt8], foreground: [UInt8], opacity: Float, mode: LayerBlendMode = .sourceOver) throws -> [UInt8] {
        _ = try MaskTestHelpers.requireDevice()
        let frame = try LayerCompositeRecipe(
            background: .cgImage(image(background)),
            layers: [ImageLayer(content: .cgImage(image(foreground)), opacity: opacity, blendMode: mode)],
            profile: .readbackQuality
        ).makeNode().makeFrame(profile: .readbackQuality)
        let output = try XCTUnwrap(frame.texture.c7.toCGImage(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setBlendMode(.copy)
        context.draw(output, in: CGRect(x: 0, y: 0, width: 2, height: 2))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: bytes, count: 4))
    }

    private func image(_ pixel: [UInt8]) throws -> CGImage {
        let data = Data(pixel + pixel + pixel + pixel)
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        return try XCTUnwrap(CGImage(
            width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }

    private func assertPixel(_ actual: [UInt8], expected: [UInt8], file: StaticString = #filePath, line: UInt = #line) {
        for channel in 0..<4 {
            XCTAssertEqual(Int(actual[channel]), Int(expected[channel]), accuracy: 2, file: file, line: line)
        }
    }
}
