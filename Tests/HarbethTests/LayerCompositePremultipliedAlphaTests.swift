//
//  LayerCompositePremultipliedAlphaTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/10/9.
//

import CoreGraphics
import CoreImage
import Metal
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

    func testExtendedSeparableModesMatchIndependentFormulas() throws {
        let backdrop: [UInt8] = [51, 102, 179, 255]
        let foreground: [UInt8] = [77, 153, 230, 255]
        let modes: [LayerBlendMode] = [.linearBurn, .divide, .vividLight, .linearLight, .pinLight, .hardMix]
        func burn(_ b: Double, _ s: Double) -> Double { s == 0 ? 0 : max(0, 1 - min(1, (1 - b) / s)) }
        func dodge(_ b: Double, _ s: Double) -> Double { s == 1 ? 1 : min(1, b / (1 - s)) }
        for mode in modes {
            let output = try composite(background: backdrop, foreground: foreground, opacity: 1, mode: mode)
            for channel in 0..<3 {
                let b = Double(backdrop[channel]) / 255
                let v = Double(foreground[channel]) / 255
                let vivid = v < 0.5 ? burn(b, 2 * v) : dodge(b, 2 * v - 1)
                let expected: Double
                switch mode {
                case .linearBurn: expected = max(0, b + v - 1)
                case .divide: expected = min(1, b / v)
                case .vividLight: expected = vivid
                case .linearLight: expected = min(1, max(0, b + 2 * v - 1))
                case .pinLight: expected = v < 0.5 ? min(b, 2 * v) : max(b, 2 * v - 1)
                case .hardMix: expected = vivid < 0.5 ? 0 : 1
                default: return XCTFail("意外模式")
                }
                XCTAssertEqual(Double(output[channel]), expected * 255, accuracy: 2, "\(mode) channel=\(channel)")
            }
        }
    }

    func testComponentModesMatchCoreImageOnChromaticAndGrayInputs() throws {
        let modes: [(LayerBlendMode, String)] = [(.hue, "CIHueBlendMode"), (.saturation, "CISaturationBlendMode"),
            (.color, "CIColorBlendMode"), (.luminosity, "CILuminosityBlendMode")]
        let vectors: [([UInt8], [UInt8])] = [([38, 102, 191, 255], [230, 51, 89, 255]),
            ([64, 64, 64, 255], [230, 51, 89, 255]), ([38, 102, 191, 255], [100, 100, 100, 255])]
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
        for (mode, name) in modes {
            for (b, v) in vectors {
                let reference = CIImage(cgImage: try image(v)).applyingFilter(name,
                    parameters: [kCIInputBackgroundImageKey: CIImage(cgImage: try image(b))])
                var bytes = [UInt8](repeating: 0, count: 16)
                context.render(reference, toBitmap: &bytes, rowBytes: 8, bounds: CGRect(x: 0, y: 0, width: 2, height: 2),
                               format: .RGBA8, colorSpace: space)
                assertPixel(try composite(background: b, foreground: v, opacity: 1, mode: mode), expected: Array(bytes.prefix(4)))
            }
        }
    }

    func testDodgeAndBurnClampAndHandleBlackWhiteEndpoints() throws {
        assertPixel(try composite(background: [0, 255, 128, 255], foreground: [255, 255, 230, 255], opacity: 1, mode: .colorDodge),
                    expected: [0, 255, 255, 255])
        assertPixel(try composite(background: [255, 0, 128, 255], foreground: [0, 0, 26, 255], opacity: 1, mode: .colorBurn),
                    expected: [255, 0, 0, 255])
    }

    func testPublicLayerCompositePreservesTextureFormatAndPremultipliedCoverage() throws {
        let background = try TextureLoader.makeTexture(width: 2, height: 2, options: [.texturePixelFormat: MTLPixelFormat.rgba16Float])
        let foreground = try TextureLoader.makeTexture(width: 2, height: 2, options: [.texturePixelFormat: MTLPixelFormat.rgba16Float])
        let b = [[Float16]](repeating: [Float16(0.2), Float16(0.3), Float16(0.4), Float16(0.5)], count: 4).flatMap { $0 }
        let v = [[Float16]](repeating: [Float16(0.4), Float16(0.1), Float16(0), Float16(0.5)], count: 4).flatMap { $0 }
        b.withUnsafeBytes { background.replace(region: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 16) }
        v.withUnsafeBytes { foreground.replace(region: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 16) }
        let output: MTLTexture = try HarbethIO(element: background, filter: LayerComposite(layerTexture: foreground, opacity: 0.5)).output()
        XCTAssertEqual(output.pixelFormat, .rgba16Float)
        var bytes = [Float16](repeating: 0, count: 16)
        XCTAssertTrue(output.c7.copyBytes(to: &bytes, bytesPerRow: 16))
        XCTAssertEqual(Float(bytes[0]), 0.35, accuracy: 0.002)
        XCTAssertEqual(Float(bytes[3]), 0.625, accuracy: 0.002)
    }

    func testFullSizeLayerUsesExactPixelCentersWithoutResampling() throws {
        let backdrop = try TextureLoader.makeTexture(width: 2, height: 4)
        let layer = try TextureLoader.makeTexture(width: 2, height: 4)
        let pixels: [UInt8] = [
            10, 30, 50, 255, 20, 40, 60, 255, 70, 90, 110, 255, 80, 100, 120, 255,
            130, 150, 170, 255, 140, 160, 180, 255, 190, 210, 230, 255, 200, 220, 240, 255
        ]
        let clear = [UInt8](repeating: 0, count: pixels.count)
        clear.withUnsafeBytes { backdrop.replace(region: MTLRegionMake2D(0, 0, 2, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        pixels.withUnsafeBytes { layer.replace(region: MTLRegionMake2D(0, 0, 2, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        let output: MTLTexture = try HarbethIO(element: backdrop, filter: LayerComposite(layerTexture: layer)).output()
        XCTAssertEqual(Array(try XCTUnwrap(output.c7.bytes())), pixels)
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
