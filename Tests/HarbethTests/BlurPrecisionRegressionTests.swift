// 由 Condy 创建于 2026/11/16。
import Metal
import XCTest
@testable import Harbeth

final class BlurPrecisionRegressionTests: XCTestCase {
    func testNonFiniteBlurParametersAreSafeForPlanningAndRendering() throws {
        let source = try NeighborhoodTestImage(width: 7, height: 5, format: .rgba32Float)
        for value: Float in [.nan, .infinity, -.infinity, -100, 0, 1000, .greatestFiniteMagnitude] {
            var deband = C7Deband(radius: value, threshold: .nan, amount: .nan, dither: .nan)
            deband.radius = value
            let bokeh = C7HexagonalBokehBlur(radius: value, brightness: .nan)
            bokeh.radius = value
            bokeh.angle = value
            XCTAssertTrue(deband.factors.allSatisfy(\.isFinite))
            XCTAssertTrue(deband.kernelPixelContract.samplingFootprint.isValid)
            XCTAssertTrue(bokeh.kernelPixelContract.samplingFootprint.isValid)
            XCTAssertTrue(bokeh.factors.allSatisfy(\.isFinite))
            XCTAssertTrue(bokeh.pipelineFilters.allSatisfy { $0.factors.allSatisfy(\.isFinite) })
            for filter: any C7FilterProtocol in [deband, bokeh] {
                let actual = try render(source.texture, filter)
                XCTAssertTrue(actual.allSatisfy(\.isFinite))
                for i in stride(from: 3, to: actual.count, by: 4) { XCTAssertEqual(actual[i], source.values[i]) }
            }
        }
    }

    func testBokehPreservesConstantHDRAndSmallAlphaAcrossBothFormats() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for alpha: Float in [1, 0.25, 0.00001] {
                let input = try NeighborhoodTestImage.make(width: 17, height: 13,
                    values: Array(repeating: [20000 * alpha, -20000 * alpha, 6000 * alpha, alpha], count: 17 * 13).flatMap { $0 }, format: format)
                let expected = try NeighborhoodTestImage.read(input)
                if alpha < 0.0001 {
                    let tiny = try NeighborhoodTestImage.make(width: 3, height: 5,
                        values: Array(repeating: [1, 0.5, 0.25, alpha], count: 15).flatMap { $0 }, format: format)
                    assertRelative(try render(tiny, C7HexagonalBokehBlur(radius: 12)), try NeighborhoodTestImage.read(tiny), tolerance: 0.001)
                }
                for cocValue: Float? in [nil, 0, 1] {
                    let coc = try cocValue.map { try NeighborhoodTestImage.make(width: 3, height: 2, values: Array(repeating: [$0, 0, 0, 1], count: 6).flatMap { $0 }) }
                    let filter = C7HexagonalBokehBlur(radius: 12, brightness: 0, angle: 17, cocTexture: coc)
                    assertRelative(try render(input, filter), expected, tolerance: format == .rgba16Float ? 0.001 : 0.00001)
                }
            }
        }
    }

    func testBokehHighlightAndFractionalCoCMatchConstantSignalReference() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage.make(width: 9, height: 7,
                values: Array(repeating: [Float](arrayLiteral: 500, 250, 100, 0.25), count: 63).flatMap { $0 }, format: format)
            let source = try NeighborhoodTestImage.read(input)
            for amount: Float in [0, 0.25, 1] {
                let coc = try NeighborhoodTestImage.make(width: 3, height: 2, values: Array(repeating: [amount, 0, 0, 1], count: 6).flatMap { $0 })
                let actual = try render(input, C7HexagonalBokehBlur(radius: 12, brightness: 2, cocTexture: coc))
                var expected = source
                for i in expected.indices where i % 4 != 3 { expected[i] *= 1 + 2 * amount }
                assertRelative(actual, expected, tolerance: 0.001)
            }
        }
    }

    func testBokehZeroRadiusAndZeroCoCPreserveFloat32Bits() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba32Float)
        let zero = try NeighborhoodTestImage.make(width: 3, height: 2, values: [Float](repeating: 0, count: 24))
        let nan = C7HexagonalBokehBlur(radius: 12); nan.radius = .nan
        for filter in [C7HexagonalBokehBlur(radius: 0, brightness: 2), nan,
                       C7HexagonalBokehBlur(radius: 12, brightness: 2, cocTexture: zero)] {
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: 17 * 13 * 16), input.texture.c7.rawBytes(maximumBytes: 17 * 13 * 16))
        }
    }

    func testDebandKeepsWhiteStraightColorAcrossVaryingCoverage() throws {
        for format in [MTLPixelFormat.rgba8Unorm, .rgba16Float, .rgba32Float] {
            var values = Array(repeating: [Float](repeating: 0.5, count: 4), count: 25).flatMap { $0 }
            for c in 0..<4 { values[c] = 0.25 }
            let input = try NeighborhoodTestImage.make(width: 5, height: 5, values: values, format: format)
            let expected = try NeighborhoodTestImage.read(input)
            let actual = try render(input, C7Deband(radius: 2, threshold: 0.5, amount: 1, dither: 0))
            assertRelative(actual, expected, tolerance: format == .rgba8Unorm ? 1.1 / 255 : 0.0001)
        }
    }

    func testDebandTransparentAndDitherOutputsRemainPremultiplied() throws {
        for format in [MTLPixelFormat.rgba8Unorm, .rgba16Float, .rgba32Float] {
            let transparent = try NeighborhoodTestImage.make(width: 5, height: 5, values: [Float](repeating: 0, count: 100), format: format)
            XCTAssertEqual(try render(transparent, C7Deband()), [Float](repeating: 0, count: 100))
            let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
            for dither: Float in [0, 0.15, 1] {
                let filter = C7Deband(radius: 4, threshold: 0.5, amount: 1, dither: dither)
                let actual = try render(input.texture, filter)
                XCTAssertEqual(actual, try render(input.texture, filter))
                for i in stride(from: 0, to: actual.count, by: 4) {
                    XCTAssertEqual(actual[i + 3], input.values[i + 3])
                    for c in 0..<3 {
                        XCTAssertTrue(actual[i + c].isFinite)
                        XCTAssertGreaterThanOrEqual(actual[i + c], 0)
                        XCTAssertLessThanOrEqual(actual[i + c], actual[i + 3] + (format == .rgba8Unorm ? 1 / 255 : 0.00001))
                    }
                }
            }
        }
    }

    func testDebandMatchesDoublePrecisionAlphaAwareReferenceWithoutDither() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage(width: 7, height: 5, format: format)
            for threshold in [0.12, 0.4] {
                let expected = debandReference(input.values, width: 7, height: 5, radius: 2, threshold: threshold, amount: 0.7)
                assertRelative(try render(input.texture, C7Deband(radius: 2, threshold: Float(threshold), amount: 0.7, dither: 0)), expected,
                               tolerance: format == .rgba16Float ? 0.001 : 0.00001)
            }
        }
    }

    func testDebandLargeOddExtentPreservesConstantColorAndCoverage() throws {
        let width = 513, height = 515
        var values = [Float](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let alpha = Float(i % 5) / 4
            for c in 0..<4 { values[i * 4 + c] = alpha }
        }
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage.make(width: width, height: height, values: values, format: format)
            assertRelative(try render(input, C7Deband(radius: 4, threshold: 0.5, amount: 1, dither: 0)), values, tolerance: 0.00001)
        }
    }

    func testDebandOpaqueCandidateRejectsTransparencyInsideHalo() throws {
        let width = 513, height = 515
        var values = Array(repeating: [Float](arrayLiteral: 0.5, 0.5, 0.5, 1), count: width * height).flatMap { $0 }
        for (x, y) in [(28, 8), (508, 514)] {
            let i = (y * width + x) * 4
            values[i] = 0.125; values[i + 1] = 0.125; values[i + 2] = 0.125; values[i + 3] = 0.25
        }
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage.make(width: width, height: height, values: values, format: format)
            assertRelative(try render(input, C7Deband(radius: 4, threshold: 0.5, amount: 1, dither: 0)), values, tolerance: 0.0001)
        }
    }

    func testDebandOpaqueSpecializationMatchesIndependentReferenceAtGroupEdges() throws {
        let width = 513, height = 515
        var values = [Float](repeating: 1, count: width * height * 4)
        for i in 0..<(width * height) { for c in 0..<3 { values[i * 4 + c] = Float((i * (c + 7)) % 251) / 250 } }
        for y in stride(from: 0, to: height, by: 8) { for x in stride(from: 0, to: width, by: 32) {
            for (px, py) in [(x, y), (min(x + 16, width - 1), min(y + 4, height - 1))] {
                let i = (py * width + px) * 4
                for c in 0..<3 { values[i + c] = 0.5 }
            }
        } }
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage.make(width: width, height: height, values: values, format: format)
            let source = try NeighborhoodTestImage.read(input)
            let actual = try render(input, C7Deband(radius: 4, threshold: 0.4, amount: 0.7, dither: 0))
            for (x, y) in [(0, 0), (31, 7), (32, 8), (511, 511), (512, 514)] {
                var crop: [Float] = []
                for dy in -4...4 { for dx in -4...4 {
                    let i = (min(max(y + dy, 0), height - 1) * width + min(max(x + dx, 0), width - 1)) * 4
                    crop.append(contentsOf: source[i..<(i + 4)])
                } }
                let reference = debandReference(crop, width: 9, height: 9, radius: 4, threshold: 0.4, amount: 0.7)
                let i = (y * width + x) * 4
                assertRelative(Array(actual[i..<(i + 4)]), Array(reference[160..<164]), tolerance: format == .rgba16Float ? 0.001 : 0.00001)
            }
        }
    }

    func testDebandZeroAmountPreservesValidFloat32BitsAndSDRClamp() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba32Float)
        let filter = C7Deband(radius: 4, amount: 0)
        let actual: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
        XCTAssertEqual(actual.c7.rawBytes(maximumBytes: 17 * 13 * 16), input.texture.c7.rawBytes(maximumBytes: 17 * 13 * 16))
        let outside = try NeighborhoodTestImage.make(width: 1, height: 1, values: [2, -0.5, 0.125, 0.25], format: .rgba32Float)
        XCTAssertEqual(try render(outside, filter), [0.25, 0, 0.125, 0.25])
        let node = try ImageNode.texture(input.texture).applying(filter).makeTexture()
        XCTAssertEqual(node.c7.rawBytes(maximumBytes: 17 * 13 * 16), input.texture.c7.rawBytes(maximumBytes: 17 * 13 * 16))
    }

    private func render(_ input: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let output: MTLTexture = try HarbethIO(element: input, filter: filter).output()
        return try NeighborhoodTestImage.read(output)
    }

    private func assertRelative(_ actual: [Float], _ expected: [Float], tolerance: Float, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for i in expected.indices {
            let limit = i % 4 == 3 ? 0 : tolerance * max(1, abs(expected[i]))
            guard actual[i].isFinite, abs(actual[i] - expected[i]) <= limit else {
                return XCTFail("分量 \(i)：实际 \(actual[i])，期望 \(expected[i])，误差界 \(limit)", file: file, line: line)
            }
        }
    }

    private func debandReference(_ values: [Float], width: Int, height: Int, radius: Int, threshold: Double, amount: Double) -> [Float] {
        func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
            let t = min(max((x - a) / (b - a), 0), 1)
            return t * t * (3 - 2 * t)
        }
        func sample(_ x: Int, _ y: Int) -> SIMD4<Double> {
            let i = (min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)) * 4
            return .init(Double(values[i]), Double(values[i + 1]), Double(values[i + 2]), Double(values[i + 3]))
        }
        func luma(_ v: SIMD4<Double>) -> Double { (v.x * 0.299 + v.y * 0.587 + v.z * 0.114) / v.w }
        var output = [Float](repeating: 0, count: values.count)
        for y in 0..<height { for x in 0..<width {
            let center = sample(x, y), index = (y * width + x) * 4
            guard center.w > 0 else { continue }
            var sum = center, contrast: Double = 0
            for dy in -radius...radius { for dx in -radius...radius where dx != 0 || dy != 0 {
                let s = sample(x + dx, y + dy)
                guard s.w > 0 else { continue }
                let delta = abs(luma(s) - luma(center))
                contrast = max(contrast, delta)
                let spatial = max(0, 1 - sqrt(Double(dx * dx + dy * dy)) / Double(radius + 1))
                let similarity = 1 - smooth(threshold * 0.35, max(threshold, 1e-5), delta)
                sum += s * (spatial * similarity)
            } }
            let strength = amount * (1 - smooth(threshold, threshold * 2.5 + 1e-5, contrast))
            for c in 0..<3 {
                let color = center[c] / center.w + strength * (sum[c] / sum.w - center[c] / center.w)
                output[index + c] = Float(min(max(color, 0), 1) * center.w)
            }
            output[index + 3] = Float(center.w)
        } }
        return output
    }
}
