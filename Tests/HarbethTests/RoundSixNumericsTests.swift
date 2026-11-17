// 由 Condy 创建于 2026/11/17。
import Metal
import XCTest
@testable import Harbeth

final class RoundSixNumericsTests: XCTestCase {
    func testMatrixDecoderRejectsWrongShapeAndBindingsRejectMutation() throws {
        for count in [0, 2, 8, 9, 10] {
            let data = try JSONEncoder().encode([Float](repeating: 1, count: count))
            if count == 9 { XCTAssertEqual(try JSONDecoder().decode(Matrix3x3.self, from: data).values.count, 9) }
            else { XCTAssertThrowsError(try JSONDecoder().decode(Matrix3x3.self, from: data)) }
        }
        var invalid = Matrix3x3.Kernel.default
        invalid.values = [1, 0]
        let input = try NeighborhoodTestImage(width: 3, height: 3, format: .rgba32Float)
        let filter = C7ConvolutionMatrix3x3(matrix: invalid)
        XCTAssertThrowsError(try output(input.texture, filter))
        XCTAssertThrowsError(try ImageNode.texture(input.texture).applying(filter).makeTexture())
    }

    func testSpatialIdentityAndZeroEffectsPreserveStoredPixels() throws {
        for format in NeighborhoodTestImage.formats {
            for (w, h) in [(1, 1), (17, 13), (17, 2160)] {
                let input = try NeighborhoodTestImage(width: w, height: h, format: format)
                let expected = input.texture.c7.rawBytes(maximumBytes: w * h * 16)
                for filter: any C7FilterProtocol in [C7ConvolutionMatrix3x3(convolutionType: .identity),
                    C7ConvolutionMatrix3x3(convolutionType: .default), C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 1), intensity: 0),
                    C7Sharpen(sharpeness: 0), C7RGBADilation(pixelRadius: 0)] {
                    XCTAssertEqual(try output(input.texture, filter).c7.rawBytes(maximumBytes: w * h * 16), expected, String(describing: filter))
                }
            }
        }
    }

    func testConvolutionMatchesAsymmetricDoubleReferenceAndSignedSpacing() throws {
        let weights: [Float] = [0.1, 0.2, -0.1, 0, 0.6, 0.3, -0.2, 0.4, 0.1]
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 9, height: 7, format: format)
            for spacing in [-2, 0, 1, 3, Int.min, Int.max] {
                var filter = C7ConvolutionMatrix3x3(matrix: .init(values: weights), intensity: 0.7)
                filter.convolutionPixel = spacing
                let step = min(max(spacing, -8), 8)
                var expected = input.values
                for y in 0..<7 { for x in 0..<9 {
                    let i = (y * 9 + x) * 4
                    for c in 0..<3 {
                        var sum: Double = 0
                        for dy in -1...1 { for dx in -1...1 {
                            let p = (min(max(y + dy * step, 0), 6) * 9 + min(max(x + dx * step, 0), 8)) * 4
                            sum += Double(input.values[p + c]) * Double(weights[(dy + 1) * 3 + dx + 1])
                        } }
                        expected[i + c] = Float(Double(input.values[i + c]) + Double(Float(0.7)) * (sum - Double(input.values[i + c])))
                    }
                } }
                input.assertPixels(try pixels(input.texture, filter), expected, tolerance: format == .rgba8Unorm ? 1.1 / 255 : 0.0015)
            }
        }
    }

    func testSharpenMatchesFourNeighborReferenceAndCentreAlpha() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
            for amount: Float in [-2, 0, 1, 2] {
                var expected = input.values
                for y in 0..<13 { for x in 0..<17 {
                    let i = (y * 17 + x) * 4
                    for c in 0..<3 {
                        var difference: Double = 0
                        for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                            let n = (min(max(y + dy, 0), 12) * 17 + min(max(x + dx, 0), 16)) * 4
                            difference += Double(input.values[i + c]) - Double(input.values[n + c])
                        }
                        expected[i + c] = Float(Double(input.values[i + c]) + Double(amount) * difference)
                    }
                } }
                input.assertPixels(try pixels(input.texture, C7Sharpen(sharpeness: amount)), expected, tolerance: format == .rgba8Unorm ? 1.1 / 255 : 0.002)
            }
        }
    }

    func testNeutralAndNormalHDRFiltersRemainFinite() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage(width: 9, height: 7, format: format, constant: 20000)
            for filter: any C7FilterProtocol in [C7Sharpen(sharpeness: 0), C7Sharpen(sharpeness: 1),
                C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 1)),
                C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 1), intensity: 0)] {
                input.assertPixels(try pixels(input.texture, filter), input.values, tolerance: 32)
            }
        }
    }

    func testSobelAndSketchMatchIndependentKernelMatrices() throws {
        let gx: [Double] = [-1,0,1,-2,0,2,-1,0,1]
        let gy: [Double] = [-1,-2,-1,0,0,0,1,2,1]
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 9, height: 9, format: format)
            for sketch in [false, true] {
                var expected = [Float](repeating: 1, count: input.values.count)
                for y in 0..<9 { for x in 0..<9 {
                    var sx: Double = 0, sy: Double = 0
                    for dy in -1...1 { for dx in -1...1 {
                        var px = x + 2 * dx, py = y + 2 * dy
                        if sketch { px = min(max(px, 0), 8); py = min(max(py, 0), 8) }
                        guard px >= 0, px < 9, py >= 0, py < 9 else { continue }
                        let i = (py * 9 + px) * 4, k = (dy + 1) * 3 + dx + 1
                        let luma = Double(input.values[i]) * Double(Float(0.2126)) + Double(input.values[i + 1]) * Double(Float(0.7152)) + Double(input.values[i + 2]) * Double(Float(0.0722))
                        sx += luma * gx[k]; sy += luma * gy[k]
                    } }
                    let edge = sqrt(sx * sx + sy * sy)
                    for c in 0..<3 { expected[(y * 9 + x) * 4 + c] = Float(sketch ? 1 - edge : edge) }
                } }
                let filter: any C7FilterProtocol = sketch ? C7Sketch(edgeStrength: 1) : C7Sobel(edgeStrength: 1)
                input.assertPixels(try pixels(input.texture, filter), expected, tolerance: format == .rgba8Unorm ? 1.1 / 255 : 0.002)
            }
        }
    }

    func testAllEightGradientImpulsesAndZeroStrength() throws {
        for (dx, dy) in [(-2,-2),(0,-2),(2,-2),(-2,0),(2,0),(-2,2),(0,2),(2,2)] {
            var values = Array(repeating: [Float](arrayLiteral: 0,0,0,1), count: 81).flatMap { $0 }
            for c in 0..<3 { values[((4 + dy) * 9 + 4 + dx) * 4 + c] = 0.25 }
            let input = try NeighborhoodTestImage.make(width: 9, height: 9, values: values)
            let expected: Float = dx != 0 && dy != 0 ? sqrt(2) * 0.25 : 0.5
            XCTAssertEqual(try pixels(input, C7Sobel())[160], expected, accuracy: 0.001)
            XCTAssertEqual(try pixels(input, C7Sketch(edgeStrength: 1))[160], 1 - expected, accuracy: 0.001)
        }
        let hdr = try NeighborhoodTestImage(width: 9, height: 7, format: .rgba32Float, constant: 20000)
        let black = try pixels(hdr.texture, C7Sobel(edgeStrength: 0)), white = try pixels(hdr.texture, C7Sketch(edgeStrength: 0))
        for i in black.indices { XCTAssertEqual(black[i], i % 4 == 3 ? 1 : 0); XCTAssertEqual(white[i], 1) }
    }

    func testUnpremultiplyRetainsEveryRepresentablePositiveCoverage() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for alpha: Float in [0, Float(Float16.leastNonzeroMagnitude), 0.00001, 0.00005, 0.001, 1] {
                let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: [alpha * 0.5, alpha * 0.25, alpha, alpha], format: format)
                let source = try NeighborhoodTestImage.read(input)
                let expected = source[3] > 0 ? [source[0] / source[3], source[1] / source[3], 1, source[3]] : source
                let actual = try pixels(input, C7UnpremultiplyAlpha())
                for c in 0..<4 { XCTAssertEqual(actual[c], expected[c], accuracy: 0.001) }
                let node = try ImageNode.texture(input).applying(C7UnpremultiplyAlpha()).makeTexture()
                XCTAssertEqual(try NeighborhoodTestImage.read(node), actual)
            }
        }
    }

    func testLegacyBlendFiniteEndpointsAndNonzeroFormula() throws {
        let baseValues: [Float] = [0,0.5,1,1, 0.25,0.25,0.25,0.5, 0.25,0.5,0.75,1]
        let overlayValues: [Float] = [0,0,0,1, 0,0,0,0, 0.5,0.5,0.5,1]
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage.make(width: 3, height: 1, values: baseValues, format: format)
            let overlay = try NeighborhoodTestImage.make(width: 3, height: 1, values: overlayValues, format: format)
            let base = try NeighborhoodTestImage.read(input), top = try NeighborhoodTestImage.read(overlay)
            for mode in [C7Blend.BlendType.colorBurn, .divide] { for intensity: Float in [0, 0.5, 1] {
                let actual = try pixels(input, C7Blend(with: mode, blendTexture: overlay, intensity: intensity))
                for i in stride(from: 0, to: base.count, by: 4) { for c in 0..<4 {
                    let b = Double(base[i + c]), s = Double(top[i + c]), ba = Double(base[i + 3]), sa = Double(top[i + 3])
                    let mapped: Double
                    if mode == .colorBurn { mapped = s == 0 ? (b == 1 ? 1 : 0) : 1 - (1 - b) / s }
                    else if c == 3 { mapped = sa + ba - sa * ba }
                    else {
                        let remainder = s * (1 - ba) + b * (1 - sa)
                        mapped = sa == 0 || s == 0 || b / s > ba / sa ? sa * ba + remainder : b * sa * sa / s + remainder
                    }
                    let expected = Float(b + Double(intensity) * (mapped - b))
                    XCTAssertTrue(actual[i + c].isFinite)
                    XCTAssertEqual(actual[i + c], expected, accuracy: 0.001)
                } }
                if intensity == 0 { XCTAssertEqual(try output(input, C7Blend(with: mode, blendTexture: overlay, intensity: 0)).c7.rawBytes(maximumBytes: 48), input.c7.rawBytes(maximumBytes: 48)) }
            } }
        }
    }

    private func output(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> MTLTexture { try HarbethIO(element: source, filter: filter).output() }
    private func pixels(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] { try NeighborhoodTestImage.read(output(source, filter)) }
}
