//
//  TextureAnalysisReadbackTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/09/04.
//

import XCTest
import Metal
@testable import Harbeth

final class TextureAnalysisReadbackTests: XCTestCase {
    func testFloat16BitDecodingPreservesFiniteAndSpecialValues() {
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0x3C00), 1, accuracy: .ulpOfOne)
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0xC000), -2, accuracy: .ulpOfOne)
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0x0001), 5.960_464_5e-8, accuracy: .leastNonzeroMagnitude)
        XCTAssertEqual(TextureAnalysisReadback.float16(bits: 0x7C00), .infinity)
        XCTAssertTrue(TextureAnalysisReadback.float16(bits: 0x7E00).isNaN)
    }

    func testPixelDecodingPreservesStorageComponentsAndBoundsAcrossFormats() throws {
        let formats: [(MTLPixelFormat, Int, Int)] = [
            (.a8Unorm, 1, 1), (.r8Unorm, 1, 1), (.rg8Unorm, 2, 1),
            (.rgba8Unorm, 4, 1), (.rgba8Unorm_srgb, 4, 1), (.bgra8Unorm, 4, 1), (.bgra8Unorm_srgb, 4, 1),
            (.r16Float, 1, 2), (.rg16Float, 2, 2), (.rgba16Float, 4, 2),
            (.r32Float, 1, 4), (.rg32Float, 2, 4), (.rgba32Float, 4, 4)
        ]
        for (format, components, componentBytes) in formats {
            var bytes = Data()
            var expected: [SIMD4<Float>] = []
            for index in 0..<6 {
                var values = componentBytes == 1
                    ? [Float(index * 32) / 255, Float(128) / 255, Float(192) / 255, 1]
                    : [Float(index - 2) / 2, 0.5, 0.75, 1]
                for channel in 0..<components {
                    if componentBytes == 1 {
                        bytes.append([UInt8(index * 32), 128, 192, 255][channel])
                    } else if componentBytes == 2 {
                        var word = Float16(values[channel]).bitPattern.littleEndian
                        withUnsafeBytes(of: &word) { bytes.append(contentsOf: $0) }
                    } else {
                        var word = values[channel].bitPattern.littleEndian
                        withUnsafeBytes(of: &word) { bytes.append(contentsOf: $0) }
                    }
                }
                if format == .a8Unorm { values = [0, 0, 0, values[0]] }
                else if components == 1 { values = [values[0], values[0], values[0], 1] }
                else if components == 2 { values = [values[0], values[1], 0, 1] }
                else if format == .bgra8Unorm || format == .bgra8Unorm_srgb { values.swapAt(0, 2) }
                expected.append(SIMD4(values[0], values[1], values[2], values[3]))
            }
            let texture = try makeTexture(format: format, width: 3, height: 2, bytes: bytes, stride: 3 * components * componentBytes)
            let readback = try XCTUnwrap(TextureAnalysisReadback(texture: texture))
            for index in 0..<6 {
                XCTAssertEqual(readback.color(x: index % 3, y: index / 3), expected[index], "format=\(format.rawValue)")
            }
            XCTAssertNil(readback.color(x: -1, y: 0))
            XCTAssertNil(readback.color(x: 0, y: -1))
            XCTAssertNil(readback.color(x: 3, y: 0))
            XCTAssertNil(readback.color(x: 0, y: 2))
        }
    }

    func testFloat32PixelDecodingPreservesSpecialBitPatterns() throws {
        let bits: [UInt32] = [0x80000000, 0x00000001, 0x7F800000, 0x7FC01234]
        let words = bits.map(\.littleEndian)
        let bytes = words.withUnsafeBytes { Data($0) }
        let texture = try makeTexture(format: .rgba32Float, width: 1, height: 1, bytes: bytes, stride: 16)
        let readback = try XCTUnwrap(TextureAnalysisReadback(texture: texture))
        let color = try XCTUnwrap(readback.color(x: 0, y: 0))
        XCTAssertEqual([color.x.bitPattern, color.y.bitPattern, color.z.bitPattern, color.w.bitPattern], bits)
    }

    private func makeTexture(format: MTLPixelFormat, width: Int, height: Int, bytes: Data, stride: Int) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        bytes.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: stride)
        }
        return texture
    }
}
