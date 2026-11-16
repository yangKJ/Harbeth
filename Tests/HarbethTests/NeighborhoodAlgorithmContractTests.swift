// 由 Condy 创建于 2026/11/16。
import XCTest
import Metal
@testable import Harbeth

final class NeighborhoodAlgorithmContractTests: XCTestCase {
    func testZeroAndInvalidParametersPreserveFloat32Bits() throws {
        let source = try fixture(width: 9, height: 5, format: .rgba32Float).texture
        let expected = try XCTUnwrap(source.c7.rawBytes(maximumBytes: 9 * 5 * 16))
        let filters: [any C7FilterProtocol] = [
            C7GaussianBlur(radius: 0), C7GaussianBlur(radius: .nan), C7MeanBlur(radius: 0), C7MeanBlur(radius: .infinity),
            C7DetailPreservingBlur(strength: 0), C7DetailEnhancer(amount: 0), C7NoiseReduction(amount: 0)
        ]
        for filter in filters {
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: expected.count), expected, String(describing: type(of: filter)))
        }
    }

    func testPackedAndIntegerGaussianDetailMatchIndependentFiveByFiveReference() throws {
        for format in [MTLPixelFormat.rgba8Unorm, .rgba16Float, .rgba32Float] {
            let input = try fixture(width: 9, height: 5, format: format)
            for strength: Float in [0, 0.3, 1] { for detail: Float in [0, 0.7, 1] {
                let filter = C7DetailPreservingBlur(strength: strength, detailPreservation: detail)
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                assertPixels(try read(output), reference(input.values, width: 9, height: 5, strength: strength, detail: detail), format: format)
            } }
            for amount: Float in [0, 0.7, 2] { for threshold: Float in [0, 0.05, 0.5] {
                let filter = C7DetailEnhancer(amount: amount, detailThreshold: threshold)
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                assertPixels(try read(output), reference(input.values, width: 9, height: 5, amount: amount, threshold: threshold), format: format)
            } }
            // 旧设备整数读取回退也必须遵循相同的数学合同。
            let fallback = IntegerDetailFilter()
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: fallback).output()
            assertPixels(try read(output), reference(input.values, width: 9, height: 5, strength: 1, detail: 0.7), format: format)
        }
    }

    func testOppositeEdgeDoesNotBleedAndSinglePixelStaysConstant() throws {
        let input = try fixture(width: 9, height: 5, format: .rgba16Float, border: true)
        let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7DetailPreservingBlur(strength: 1, detailPreservation: 0)).output()
        let pixels = try read(output)
        XCTAssertEqual(pixels[(2 * 9) * 4], 0.25, accuracy: 0.001)
        XCTAssertEqual(pixels[4 * 4 + 1], 0.25, accuracy: 0.001)
        let point = try fixture(width: 1, height: 1, format: .rgba32Float, constant: 0.25)
        for filter in [C7GaussianBlur(radius: 20), C7MeanBlur(radius: 20), C7DetailPreservingBlur(strength: 1), C7DetailEnhancer(amount: 1)] as [any C7FilterProtocol] {
            let value: MTLTexture = try HarbethIO(element: point.texture, filter: filter).output()
            assertPixels(try read(value), point.values, format: .rgba32Float)
        }
    }

    func testHDRConstantsAndGaussianNormalizedSpacingRemainCorrect() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for value: Float in [10000, 20000, 65504] {
                let input = try fixture(width: 9, height: 5, format: format, constant: value)
                for radius: Float in [0, 20] {
                    for filter in [C7GaussianBlur(radius: radius), C7MeanBlur(radius: radius)] as [any C7FilterProtocol] {
                        let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                        let pixels = try read(output)
                        XCTAssertTrue(pixels.allSatisfy(\.isFinite))
                        for i in pixels.indices { XCTAssertEqual(pixels[i], input.values[i], accuracy: max(0.001, abs(input.values[i]) * 0.001)) }
                    }
                }
            }
        }
        let input = try fixture(width: 9, height: 5, format: .rgba32Float)
        for gaussian in [true, false] {
            let filter: any C7FilterProtocol = gaussian ? C7GaussianBlur(radius: 20) : C7MeanBlur(radius: 20)
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            var expected = [Float](repeating: 0, count: input.values.count)
            for y in 0..<5 { for x in 0..<9 { for c in 0..<4 {
                var sum = 0.0
                let offsets = gaussian ? [-1, 0, 1] : [-1, 1]
                let weights = [1.0, 2.0, 1.0]
                for dy in offsets { for dx in offsets {
                    let sx = Int(min(max(Float(x) + Float(dx) * 0.2 * 9, 0), 8))
                    let sy = Int(min(max(Float(y) + Float(dy) * 0.2 * 5, 0), 4))
                    let weight = gaussian ? weights[dx + 1] * weights[dy + 1] / 16 : 0.25
                    sum += Double(input.values[(sy * 9 + sx) * 4 + c]) * weight
                } }
                expected[(y * 9 + x) * 4 + c] = Float(sum)
            } } }
            assertPixels(try read(output), expected, format: .rgba32Float)
        }
    }

    func testAuthoringDestinationSizeKeepsNormalizedSamplingCoordinates() throws {
        let source = try fixture(width: 9, height: 5, format: .rgba32Float)
        for (width, height) in [(3,2), (17,11)] {
            for gaussian in [true, false] { for radius: Float in [0,20] {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
                d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
                let destination = try XCTUnwrap(source.texture.device.makeTexture(descriptor: d))
                let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
                let filter: any C7FilterProtocol = gaussian ? C7GaussianBlur(radius: radius) : C7MeanBlur(radius: radius)
                _ = try filter.applyAtTexture(form: source.texture, to: destination, for: command)
                try command.commitAndWaitUntilCompleted(identifier: "DifferentDestination")
                var expected = [Float](repeating: 0, count: width * height * 4)
                let offsets = radius == 0 ? [0] : gaussian ? [-1,0,1] : [-1,1]
                let weights: [Double] = [1,2,1]
                for y in 0..<height { for x in 0..<width { for c in 0..<4 {
                    let baseX = Float(x) / Float(width) * 9, baseY = Float(y) / Float(height) * 5
                    var sum = 0.0
                    for dy in offsets { for dx in offsets {
                        let sx = Int(min(max(baseX + Float(dx) * (radius / 100) * 9, 0), 8))
                        let sy = Int(min(max(baseY + Float(dy) * (radius / 100) * 5, 0), 4))
                        let weight: Double = radius == 0 ? 1 : gaussian ? weights[dx+1] * weights[dy+1] / 16 : 0.25
                        sum += Double(source.values[(sy * 9 + sx) * 4 + c]) * weight
                    } }
                    expected[(y * width + x) * 4 + c] = Float(sum)
                } } }
                assertPixels(try read(destination), expected, format: .rgba32Float)
            } }
        }
    }

    private func reference(_ p: [Float], width: Int, height: Int, strength: Float = 1, detail: Float = 0,
                           amount: Float? = nil, threshold: Float = 0) -> [Float] {
        let weights = [1.0, 4, 6, 4, 1]
        var result = p
        for y in 0..<height { for x in 0..<width {
            let offset = (y * width + x) * 4
            var blur = [Double](repeating: 0, count: 4)
            for dy in -2...2 { for dx in -2...2 {
                let sample = (min(max(y + dy, 0), height - 1) * width + min(max(x + dx, 0), width - 1)) * 4
                for c in 0..<4 { blur[c] += Double(p[sample + c]) * weights[dx + 2] * weights[dy + 2] / 256 }
            } }
            if let amount {
                let mask = (0..<4).map { Double(p[offset + $0]) - blur[$0] }
                let maskStrength = (0..<3).reduce(0.0) { $0 + abs(mask[$1]) * 0.333 }
                let t = threshold > 0 ? min(max(maskStrength / Double(threshold), 0), 1) : 1
                let adjusted = Double(amount) * (maskStrength < Double(threshold) ? t * t * (3 - 2 * t) : 1)
                for c in 0..<3 { result[offset + c] = Float(Double(p[offset + c]) + mask[c] * adjusted) }
            } else {
                for c in 0..<4 {
                    let center = Double(p[offset + c])
                    result[offset + c] = Float(center + (blur[c] + (center - blur[c]) * Double(detail) - center) * Double(strength))
                }
            }
        } }
        return result
    }

    private func assertPixels(_ actual: [Float], _ expected: [Float], format: MTLPixelFormat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (a, e) in zip(actual, expected) {
            let value = format == .rgba8Unorm ? min(max(e, 0), 1) : e
            XCTAssertEqual(a, value, accuracy: format == .rgba8Unorm ? 1.0 / 255 : 0.002, file: file, line: line)
        }
    }

    private func fixture(width: Int, height: Int, format: MTLPixelFormat, constant: Float? = nil, border: Bool = false) throws -> (texture: MTLTexture, values: [Float]) {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let t = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: d))
        var values = [Float](repeating: 1, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let i = (y * width + x) * 4
            let alpha: Float = constant != nil || border ? 1 : (x + y) % 5 == 0 ? 0 : 0.3 + 0.7 * Float(y) / Float(max(height - 1, 1))
            values[i] = constant ?? (border ? (x == width - 1 ? 1 : 0.25) : Float((x * x + y * 3) % 17) / 17 * alpha)
            values[i+1] = constant ?? (border ? (y == height - 1 ? 1 : 0.25) : Float((x + y * y) % 19) / 19 * alpha)
            values[i+2] = constant ?? Float((x + y) % 7) / 7 * alpha
            values[i+3] = alpha
        } }
        if format == .rgba8Unorm {
            let bytes = values.map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
            bytes.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        } else if format == .rgba16Float {
            let half = values.map { Float16($0) }
            half.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        } else {
            values.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        }
        return (t, try read(t))
    }

    private func read(_ texture: MTLTexture) throws -> [Float] {
        let stride = texture.pixelFormat == .rgba8Unorm ? 4 : texture.pixelFormat == .rgba16Float ? 8 : 16
        let data = try XCTUnwrap(texture.c7.rawBytes(maximumBytes: texture.width * texture.height * stride))
        if stride == 4 { return data.map { Float($0) / 255 } }
        if stride == 8 { return data.withUnsafeBytes { $0.bindMemory(to: UInt16.self).map { Float(Float16(bitPattern: $0)) } } }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

private struct IntegerDetailFilter: C7FilterProtocol {
    var modifier: ModifierEnum { .compute(kernel: "C7DetailPreservingBlur") }
    var factors: [Float] { [1, 0.7] }
}
