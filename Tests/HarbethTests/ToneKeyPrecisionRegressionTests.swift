// 由 Condy 创建于 2026/11/17。
import Metal
import XCTest
@testable import Harbeth

final class ToneKeyPrecisionRegressionTests: XCTestCase {
    func testTallWideAndSingleColumnToneAdjustmentsMatchStraightColorReference() throws {
        for format in ColorMathPixels.formats { for (w, h) in [(3, 7), (7, 3), (1, 17)] {
            let source = try ColorMathPixels.fixture(width: w, height: h, format: format)
            let input = try ColorMathPixels.read(source)
            for highlights in [false, true] { for amount: Float in [-0.3, 0, 0.3] {
                let filter: any C7FilterProtocol = highlights ? C7Highlights(highlight: amount) : C7Shadows(shadow: amount)
                var expected = input
                for i in stride(from: 0, to: input.count, by: 4) {
                    let a = Double(input[i + 3])
                    if a == 0 { for c in 0..<4 { expected[i + c] = 0 }; continue }
                    let l = (Double(input[i]) * 0.2126 + Double(input[i + 1]) * 0.7152 + Double(input[i + 2]) * 0.0722) / a
                    let x = min(max(highlights ? (l - 0.5) / 0.5 : l / 0.5, 0), 1)
                    let smooth = x * x * (3 - 2 * x), weight = highlights ? smooth : 1 - smooth
                    for c in 0..<3 { expected[i + c] += Float(Double(amount) * weight * a) }
                }
                ColorMathPixels.assertPixels(try output(source, filter), expected, format: format)
            } }
        } }
    }

    func testNeutralToneDefaultsPreserveFloat32HDRAndInvalidParameters() throws {
        let values: [Float] = [30000.003, 20000.007, -2.1, 1, 0.013, 0.027, 0.011, 0.05]
        let source = try ColorMathPixels.make(width: 2, height: 1, values: values, format: .rgba32Float)
        for filter: any C7FilterProtocol in [C7HighlightShadow(), C7HighlightShadow(highlights: .nan, shadows: .nan), C7Highlights(highlight: 0), C7Shadows(shadow: 0)] {
            XCTAssertEqual(try output(source, filter), values)
        }
        XCTAssertEqual(C7HighlightShadow().highlights, 1)
    }

    func testChromaDetectionIsIndependentOfCoverageAndReplacementIsAssociated() throws {
        for format in ColorMathPixels.formats { for alpha: Float in [0, 0.05, 0.25, 1] {
            let source = try ColorMathPixels.make(width: 1, height: 1, values: [0, alpha, 0, alpha], format: format)
            XCTAssertEqual(try output(source, C7ChromaKey(smoothing: 0)), [0, 0, 0, 0])
            let replaced = try output(source, C7ChromaKey(smoothing: 0, replace: C7Color(red: 1, green: 0, blue: 0, alpha: 0.25)))
            ColorMathPixels.assertPixels(replaced, [0.25, 0, 0, 0.25], format: format)
        } }
        let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.25, 0, 0, 0.25], format: .rgba32Float)
        XCTAssertEqual(try output(source, C7ChromaKey(thresholdSensitivity: 0, smoothing: 0)), [0.25, 0, 0, 0.25])
        XCTAssertTrue(try output(source, C7ChromaKey(thresholdSensitivity: .nan, smoothing: .nan)).allSatisfy(\.isFinite))
        for alpha: Float in [0.25, 1] {
            let rgb: [Double] = [0.05, 0.8, 0.05]
            let sample = try ColorMathPixels.make(width: 1, height: 1, values: rgb.map { Float($0) * alpha } + [alpha], format: .rgba32Float)
            let y = rgb[0] * 0.2989 + rgb[1] * 0.5866 + rgb[2] * 0.1145
            let cr = 0.7132 * (rgb[0] - y), cb = 0.5647 * (rgb[2] - y)
            let keyCr = -0.7132 * 0.5866, keyCb = -0.5647 * 0.5866
            let distance = sqrt(pow(cr - keyCr, 2) + pow(cb - keyCb, 2))
            let t = min(max((distance - 0.1) / 0.1, 0), 1), matte = Float(t * t * (3 - 2 * t))
            ColorMathPixels.assertPixels(try output(sample, C7ChromaKey(thresholdSensitivity: 0.1, smoothing: 0.1)), (rgb.map { Float($0) * alpha } + [alpha]).map { $0 * matte }, format: .rgba32Float)
        }
    }

    func testFloat32GradientAndInteger16ConversionDoNotPassThroughHalf() throws {
        let values = (0..<1024).flatMap { x -> [Float] in let v = Float(32768 + x) / 65535; return [v, v, v, 1] }
        let source = try ColorMathPixels.make(width: 1024, height: 1, values: values, format: .rgba32Float)
        XCTAssertEqual(try output(source, C7PixelFormatChange()), values)
        for bits in [1, 8, 10, 12, 16] {
            let actual = try output(source, C7OutputQuantization(bitDepth: bits, pattern: .none))
            let levels = Float((1 << bits) - 1)
            for x in 0..<1024 {
                let reference = floor(values[x * 4] * levels + 0.5) / levels
                XCTAssertEqual(actual[x * 4], reference, accuracy: 0.000001)
            }
            if bits == 16 { XCTAssertEqual(Set(stride(from: 0, to: actual.count, by: 4).map { actual[$0] }).count, 1024) }
        }
        let frame = RenderedFrame(texture: source, profile: .exportQuality, generation: 1, identifier: "precision.UInt16")
        let converted = try frame.converted(to: .init(pixelFormat: .init(pixelFormat: .rgba16Unorm, preservesInput: false), quantization: .disabled))
        XCTAssertEqual(converted.texture.pixelFormat, .rgba16Unorm)
        let device = HarbethContext.shared.device, destination = converted.texture
        let command = try XCTUnwrap(device.makeCommandQueue()?.makeCommandBuffer())
        let buffer = try XCTUnwrap(device.makeBuffer(length: 8192, options: .storageModeShared)), blit = try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from: destination, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .init(x: 0, y: 0, z: 0), sourceSize: .init(width: 1024, height: 1, depth: 1), to: buffer, destinationOffset: 0, destinationBytesPerRow: 8192, destinationBytesPerImage: 8192)
        blit.endEncoding(); command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(command.status, .completed)
        let codes = buffer.contents().bindMemory(to: UInt16.self, capacity: 4096)
        for i in values.indices { XCTAssertLessThanOrEqual(abs(Int(codes[i]) - Int((values[i] * 65535).rounded())), 1) }
    }

    private func output(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let result: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        return try ColorMathPixels.read(result)
    }
}
