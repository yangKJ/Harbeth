// 由 Condy 创建于 2026/11/17。
import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class MatrixVectorRegressionTests: XCTestCase {
    func testDecodingRejectsEveryWrongShapeAndRetainsValidPayloads() throws {
        for count in [0, 2, 4, 15, 16, 17] {
            let data = try JSONEncoder().encode(Array(repeating: Float(1), count: count))
            if count == 16 { XCTAssertEqual(try JSONDecoder().decode(Matrix4x4.self, from: data).values.count, 16) }
            else { XCTAssertThrowsError(try JSONDecoder().decode(Matrix4x4.self, from: data)) }
            if count == 4 { XCTAssertEqual(try JSONDecoder().decode(Vector4.self, from: data).values.count, 4) }
            else { XCTAssertThrowsError(try JSONDecoder().decode(Vector4.self, from: data)) }
        }
        for (m, v) in [(16, 4), (2, 4), (16, 2), (17, 5)] {
            let data = try JSONSerialization.data(withJSONObject: ["matrix4x4": Array(repeating: 1, count: m), "vector4": Array(repeating: 0, count: v)])
            if m == 16 && v == 4 { XCTAssertEqual(try JSONDecoder().decode(Matrix4x5.self, from: data).matrix4x4.values.count, 16) }
            else { XCTAssertThrowsError(try JSONDecoder().decode(Matrix4x5.self, from: data)) }
        }
        let value = KernelParameterBindingValue.vector4(.init(values: [0.1, 0.2, 0.3, 0.4]))
        XCTAssertEqual(try JSONDecoder().decode(KernelParameterBindingValue.self, from: JSONEncoder().encode(value)), value)
        XCTAssertEqual(value.argumentDataType, .float4)
    }

    func testMutationFailsBeforeSIMDConversionThroughBothEntries() throws {
        let source = try ColorMathPixels.fixture(width: 3, height: 7, format: .rgba32Float)
        var matrix = Matrix4x4.Color.identity, vector = Vector4.zero
        matrix.values = [1, 2]; vector.values = [1, 2]
        for filter: any C7FilterProtocol in [C7ColorMatrix4x4(matrix: matrix), C7ColorMatrix4x4(matrix: .Color.identity, offset: vector), C7ColorVector4(vector: vector)] {
            XCTAssertFalse(filter.kernelDescriptor().parameterBindings.isEmpty)
            XCTAssertThrowsError(try HarbethIO(element: source, filter: filter).output())
            XCTAssertThrowsError(try ImageNode.texture(source).applying(filter).makeFrame())
        }
    }

    func testInvalidDeferredVectorReturnsErrorThroughAsyncRoutes() async throws {
        let source = try ColorMathPixels.fixture(width: 3, height: 1, format: .rgba32Float)
        var vector = Vector4.zero
        vector.values = [1, 2]
        let filter = C7ColorVector4(vector: vector)
        do {
            let _: MTLTexture = try await HarbethIO(element: source, filter: filter).transmitOutput()
            XCTFail("非法向量必须返回错误")
        } catch { XCTAssertTrue(error is HarbethError) }
        do {
            _ = try await ImageNode.texture(source).applying(filter).makeFrameAsync()
            XCTFail("非法向量必须返回错误")
        } catch { XCTAssertTrue(error is HarbethError) }
    }

    func testRawRowMajorAffineMathMatchesDoubleAcrossStorageAndIntensity() throws {
        let m: [Float] = [1.1, 0.2, -0.1, 0.3, 0.1, 0.8, 0.2, 0, -0.2, 0.1, 1.2, 0.1, 0.1, 0.2, 0, 0.5]
        let offset: [Float] = [0.03, -0.02, 0.01, 0.04]
        let values45 = (0..<4).flatMap { Array(m[$0 * 4..<$0 * 4 + 4]) + [offset[$0]] }
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.fixture(width: 7, height: 3, format: format)
            let input = try ColorMathPixels.read(source)
            for t: Float in [0, 0.4, 1] {
                var expected = input
                for i in stride(from: 0, to: input.count, by: 4) { for row in 0..<4 {
                    let dot = (0..<4).reduce(Double(offset[row])) { $0 + Double(m[row * 4 + $1]) * Double(input[i + $1]) }
                    expected[i + row] = Float(Double(input[i + row]) * (1 - Double(t)) + dot * Double(t))
                } }
                for filter: any C7FilterProtocol in [C7ColorMatrix4x4(matrix: .init(rowMajor: m), offset: .init(values: offset), intensity: t), C7ColorMatrix4x5(matrix: .init(values: values45), intensity: t)] {
                    ColorMathPixels.assertPixels(try pixels(source, filter), expected, format: format)
                }
                let vectorExpected = input.enumerated().map { $0.element + offset[$0.offset % 4] * t }
                ColorMathPixels.assertPixels(try pixels(source, C7ColorVector4(vector: .init(values: offset), intensity: t)), vectorExpected, format: format)
            }
        }
    }

    func testZeroAndIdentityKeepFloat32AndBypassUnrepresentableIntermediateHDR() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let source = try ColorMathPixels.make(width: 1, height: 1, values: [30000.003, 20000.007, -2.1, 1], format: format)
            let expected = source.c7.rawBytes(maximumBytes: 16)
            let huge = Matrix4x4(values: [10, 10, 10, 0, 10, 10, 10, 0, 10, 10, 10, 0, 0, 0, 0, 1])
            let matrix45 = Matrix4x5(values: (0..<4).flatMap { Array(huge.values[$0 * 4..<$0 * 4 + 4]) + [Float(65504)] })
            for filter: any C7FilterProtocol in [C7ColorMatrix4x4(matrix: huge, intensity: 0), C7ColorMatrix4x5(matrix: matrix45, intensity: 0), C7ColorVector4(vector: .init(values: [65504, 65504, 65504, 0]), intensity: 0), C7ColorMatrix4x4(matrix: .Color.identity), C7ColorVector4(vector: .zero)] {
                let result: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                XCTAssertEqual(result.c7.rawBytes(maximumBytes: 16), expected)
            }
        }
    }

    func testNamedHelpersRespectAssociatedInvertOpacityAndGreenAxis() throws {
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.1, 0.2, 0.3, 0.5], format: format)
            let p = try ColorMathPixels.read(source)
            for matrix in [Matrix4x4.Color.invert, .Color.negative] {
                ColorMathPixels.assertPixels(try pixels(source, C7ColorMatrix4x4(matrix: matrix)), [p[3] - p[0], p[3] - p[1], p[3] - p[2], p[3]], format: format)
            }
            for t: Float in [0, 0.3, 1] {
                ColorMathPixels.assertPixels(try pixels(source, C7ColorMatrix4x4(matrix: .Color.decreasingOpacity(t))), p.map { $0 * t }, format: format)
            }
            for degree: Float in [0, 90, 180] {
                let radians = Double(degree) * .pi / 180
                let expected = [Float(Double(p[0]) * cos(radians) - Double(p[2]) * sin(radians)), p[1], Float(Double(p[0]) * sin(radians) + Double(p[2]) * cos(radians)), p[3]]
                ColorMathPixels.assertPixels(try pixels(source, C7ColorMatrix4x4(matrix: .Color.axix_green_rotate(degree))), expected, format: format)
            }
        }
    }

    func testOpacityHelperDowngradesKnownOpaqueFrameAndCompositesClear() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral: 64, 128, 192, 255)) as CFData))
        let image = try XCTUnwrap(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let frame = try ImageNode.cgImage(image).applying(C7ColorMatrix4x4(matrix: .Color.decreasingOpacity(0))).makeFrame()
        XCTAssertEqual(frame.alphaType, .premultiplied)
        XCTAssertEqual(try ColorMathPixels.read(frame.texture), [0, 0, 0, 0])
        let black = try ColorMathPixels.make(width: 1, height: 1, values: [0, 0, 0, 1], format: .rgba16Float)
        XCTAssertEqual(try pixels(black, RenderLayerComposite(layerTexture: frame.texture)), [0, 0, 0, 1])
    }

    func testRawAlphaMatrixKeepsStraightSourceAssociationAndRawRGB() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral: 128, 64, 32, 128)) as CFData))
        let image = try XCTUnwrap(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        var matrix = Matrix4x4.Color.identity
        matrix.values[15] = 0.5
        let frame = try ImageNode.cgImage(image).applying(C7ColorMatrix4x4(matrix: matrix)).makeFrame(profile: .exportQuality)
        XCTAssertEqual(frame.alphaType, .nonPremultiplied)
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), [Float(128) / 255, Float(64) / 255, Float(32) / 255, Float(64) / 255], format: frame.texture.pixelFormat)
    }

    private func pixels(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let result: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        return try ColorMathPixels.read(result)
    }
}
