//
//  LegacyNeighborhoodRegressionTests.metal
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class LegacyNeighborhoodRegressionTests: XCTestCase {
    func testZeroAndInvalidParametersKeepFloat32Pixels() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba32Float)
        let filters: [any C7FilterProtocol] = [
            C7CircleBlur(radius: 10, amount: 0), C7CircleBlur(radius: 10, amount: -3), C7CircleBlur(radius: 0, amount: 20),
            C7CircleBlur(radius: 10, amount: Int.max),
            C7CircleBlur(radius: .nan), C7CircleBlur(radius: .infinity),
            C7UnsharpMask(radius: 0, intensity: 1), C7UnsharpMask(radius: 10, intensity: 0)
        ]
        let bytes = try XCTUnwrap(input.texture.c7.rawBytes(maximumBytes: 17 * 13 * 16))
        for filter in filters {
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: bytes.count), bytes, String(describing: filter))
        }
    }

    func testCircleMatchesIndependentCircularAverageAndClampedEdges() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
            let radius: Float = 18.1
            let count = 19
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7CircleBlur(radius: radius, amount: count)).output()
            let offset = Double(Float(Float16(radius) / Float16(100)))
            var expected = [Float](repeating: 0, count: input.values.count)
            for y in 0..<13 { for x in 0..<17 { for c in 0..<4 {
                var sum: Double = 0
                for sample in 0..<count {
                    let angle = Double(sample) / Double(count) * Double.pi * 2
                    let sx = Int(min(max(Double(x) + cos(angle) * offset * 17, 0), 16))
                    let sy = Int(min(max(Double(y) + sin(angle) * offset * 13, 0), 12))
                    sum += Double(input.values[(sy * 17 + sx) * 4 + c]) / Double(count)
                }
                expected[(y * 17 + x) * 4 + c] = Float(sum)
            } } }
            input.assertPixels(try NeighborhoodTestImage.read(output), expected)
        }
    }

    func testCircleHDRConstantsDoNotOverflowBeforeAveraging() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for value: Float in [10000, 65504] {
                let input = try NeighborhoodTestImage(width: 9, height: 7, format: format, constant: value)
                for radius: Float in [0, 20] {
                    let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7CircleBlur(radius: radius, amount: 20)).output()
                    input.assertPixels(try NeighborhoodTestImage.read(output), input.values, tolerance: max(0.001, value * 0.001))
                }
            }
        }
    }

    func testEdgeGlowConstantImageHasNoArtificialBorder() throws {
        for format in NeighborhoodTestImage.formats {
            for (width, height) in [(1, 1), (17, 13)] {
                let input = try NeighborhoodTestImage(width: width, height: height, format: format, constant: 0.5)
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7EdgeGlow(time: 0.2, spacing: 0.1)).output()
                input.assertPixels(try NeighborhoodTestImage.read(output), input.values)
            }
        }
    }

    func testEdgeGlowMatchesIndependentSignedBoundaryConvolution() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba16Float)
        let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7EdgeGlow(time: 0.2, spacing: 0.03)).output()
        var expected = input.values
        let phase = Double(Float(Float16(0.2) * Float16(5)))
        for y in 0..<13 { for x in 0..<17 {
            var edge = [Double](repeating: 0, count: 4)
            for dy in -1...1 { for dx in -1...1 {
                let weight: Double = dx == 0 && dy == 0 ? 8 : -1
                let sample = (min(max(y + dy, 0), 12) * 17 + min(max(x + dx, 0), 16)) * 4
                for c in 0..<4 { edge[c] += Double(input.values[sample + c]) * weight }
            } }
            if sqrt(edge.reduce(0) { $0 + $1 * $1 }) > Double(Float(Float16(0.03))) {
                for c in 0..<4 {
                    let green: Double = c == 1 || c == 3 ? 1 : 0
                    expected[(y * 17 + x) * 4 + c] = Float(green * sin(phase) + Double(input.values[(y * 17 + x) * 4 + c]) * cos(phase))
                }
            }
        } }
        input.assertPixels(try NeighborhoodTestImage.read(output), expected, tolerance: 0.002)
    }

    func testUnsharpMatchesDoubleGaussianReferenceAndRetainsSDRClamp() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 9, height: 7, format: format)
            for radius in [2, 4, 10] {
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7UnsharpMask(radius: Float(radius), intensity: 1.3, threshold: 0.037)).output()
                let sigma = max(Double(radius) * 0.5, 0.75)
                var expected = input.values
                for y in 0..<7 { for x in 0..<9 {
                    var blur = [Double](repeating: 0, count: 3), total: Double = 0
                    for dy in -radius...radius { for dx in -radius...radius {
                        let w = exp(-Double(dx * dx + dy * dy) / (2 * sigma * sigma))
                        let i = (min(max(y + dy, 0), 6) * 9 + min(max(x + dx, 0), 8)) * 4
                        total += w
                        for c in 0..<3 { blur[c] += Double(input.values[i + c]) * w }
                    } }
                    let i = (y * 9 + x) * 4
                    let detail = (0..<3).map { Double(input.values[i + $0]) - blur[$0] / total }
                    let mask = detail.map(abs).max()! > Double(Float(0.037)) ? 1.0 : 0
                    for c in 0..<3 { expected[i + c] = Float(min(max(Double(input.values[i + c]) + detail[c] * Double(Float(1.3)) * mask, 0), 1)) }
                } }
                input.assertPixels(try NeighborhoodTestImage.read(output), expected)
            }
        }
    }
}

/// 输入先量化到真实存储格式；参考算法读取量化后的值。
struct NeighborhoodTestImage {
    static let formats: [MTLPixelFormat] = [.rgba8Unorm, .rgba16Float, .rgba32Float]
    let texture: MTLTexture
    let values: [Float]

    init(width: Int, height: Int, format: MTLPixelFormat, constant: Float? = nil) throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: d))
        var data = [Float](repeating: 1, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let i = (y * width + x) * 4
            let alpha: Float = constant != nil ? 1 : (x + y) % 5 == 0 ? 0 : 0.2 + 0.8 * Float(y + 1) / Float(height)
            data[i] = constant ?? Float((x * 13 + y * 3) % 17) / 17 * alpha
            data[i + 1] = constant ?? Float((x * 3 + y * 7) % 19) / 19 * alpha
            data[i + 2] = constant ?? Float((x + y * 11) % 23) / 23 * alpha
            data[i + 3] = alpha
        } }
        if format == .rgba8Unorm {
            let bytes = data.map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
            bytes.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        } else if format == .rgba16Float {
            let half = data.map { Float16($0) }
            half.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        } else {
            data.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        }
        self.texture = texture
        values = try Self.read(texture)
    }

    static func read(_ texture: MTLTexture) throws -> [Float] {
        let size = texture.pixelFormat == .rgba8Unorm ? 4 : texture.pixelFormat == .rgba16Float ? 8 : 16
        let data = try XCTUnwrap(texture.c7.rawBytes(maximumBytes: texture.width * texture.height * size))
        if size == 4 { return data.map { Float($0) / 255 } }
        return data.withUnsafeBytes { bytes in
            size == 8 ? bytes.bindMemory(to: UInt16.self).map { Float(Float16(bitPattern: $0)) } : Array(bytes.bindMemory(to: Float.self))
        }
    }

    func assertPixels(_ actual: [Float], _ expected: [Float], tolerance: Float? = nil, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        let epsilon = tolerance ?? (texture.pixelFormat == .rgba8Unorm ? 1.1 / 255 : texture.pixelFormat == .rgba16Float ? 0.001 : 0.00002)
        for i in actual.indices {
            let reference = texture.pixelFormat == .rgba8Unorm ? (min(max(expected[i], 0), 1) * 255).rounded() / 255 : expected[i]
            let limit = i % 4 == 3 && texture.pixelFormat != .rgba8Unorm ? min(epsilon, 0.002) : epsilon
            if !actual[i].isFinite || abs(actual[i] - reference) > limit {
                XCTFail("分量 \(i)：\(actual[i])，期望 \(reference)，误差界 \(limit)", file: file, line: line)
                return
            }
        }
    }
}
