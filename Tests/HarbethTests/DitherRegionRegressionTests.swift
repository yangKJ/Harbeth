// 由 Condy 创建于 2026/11/17。
import Metal
import XCTest
@testable import Harbeth

final class DitherRegionRegressionTests: XCTestCase {
    func testAsyncPublicRoutesMatchCompletedSynchronousPixelsAndPreserveSource() async throws {
        let source = try ColorMathPixels.fixture(width: 65, height: 63, format: .rgba16Float)
        let before = source.c7.rawBytes(maximumBytes: 65 * 63 * 8)
        for size in [4, 16, 32] {
            let filter = C7OrderedDither(levels: 8, pixelSize: size)
            let expected: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            let actual: MTLTexture = try await HarbethIO(element: source, filter: filter).transmitOutput()
            XCTAssertEqual(actual.c7.rawBytes(maximumBytes: 65 * 63 * 8), expected.c7.rawBytes(maximumBytes: 65 * 63 * 8))
            let node = ImageNode.texture(source).applying(filter)
            let synchronous = try node.makeFrame(), asynchronous = try await node.makeFrameAsync()
            XCTAssertEqual(try ColorMathPixels.read(asynchronous.texture), try ColorMathPixels.read(synchronous.texture))
            XCTAssertEqual(asynchronous.alphaType, synchronous.alphaType)
        }
        XCTAssertEqual(source.c7.rawBytes(maximumBytes: 65 * 63 * 8), before)
    }

    func testCompactDispatchMatchesCanonicalKernelForPartialCellsAndStorage() throws {
        for format in ColorMathPixels.formats { for (w, h) in [(1, 1), (17, 13), (65, 63)] {
            let input = try ColorMathPixels.fixture(width: w, height: h, format: format)
            for size in [1, 2, 4, 8, 16, 32] { for pattern in [ImageDitherPattern.none, .ordered4x4] {
                let base = C7OrderedDither(levels: 8, pixelSize: size, pattern: pattern, seed: 17)
                let direct = RegionDither(base: base, context: [0, 0, Float(w), Float(h), 0, 0, Float(w), Float(h)])
                let expected: MTLTexture = try HarbethIO(element: input, filter: direct).output()
                let actual: MTLTexture = try HarbethIO(element: input, filter: base).output()
                XCTAssertEqual(actual.c7.rawBytes(maximumBytes: w * h * 16), expected.c7.rawBytes(maximumBytes: w * h * 16))
            } }
        } }
    }

    func testCellAveragePreservesTinyPositiveAlphaAndIndependentPaletteReference() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let values: [Float] = [0.00001, 0, 0, 0.00001, 0, 0.00003, 0, 0.00003, 0, 0, 0, 0]
            let input = try ColorMathPixels.make(width: 3, height: 1, values: values, format: format)
            let source = try ColorMathPixels.read(input)
            let actual: MTLTexture = try HarbethIO(element: input, filter: C7OrderedDither(levels: 5, pixelSize: 4, pattern: .none)).output()
            let output = try ColorMathPixels.read(actual)
            let alpha = source[3] + source[7]
            let red = (source[0] / alpha * 4).rounded() / 4, green = (source[5] / alpha * 4).rounded() / 4
            for x in 0..<3 {
                XCTAssertEqual(output[x * 4 + 3], source[x * 4 + 3])
                XCTAssertEqual(output[x * 4], red * source[x * 4 + 3], accuracy: 0.0000001)
                XCTAssertEqual(output[x * 4 + 1], green * source[x * 4 + 3], accuracy: 0.0000001)
            }
            XCTAssertGreaterThan(output[0], 0)
            XCTAssertGreaterThan(output[5], 0)
        }
    }

    func testInputHaloAndOutputOriginUseIndependentCoordinates() throws {
        let full = try ColorMathPixels.fixture(width: 16, height: 16, format: .rgba32Float)
        let source = try ColorMathPixels.read(full)
        var haloValues: [Float] = []
        for y in 4..<12 { for x in 4..<12 { haloValues += source[(y * 16 + x) * 4..<(y * 16 + x) * 4 + 4] } }
        let halo = try ColorMathPixels.make(width: 8, height: 8, values: haloValues, format: .rgba32Float)
        for size in [1, 2, 4] { for pattern in [ImageDitherPattern.none, .ordered4x4, .ordered8x8, .interleavedGradient] {
            let filters: [any C7FilterProtocol] = [C7OrderedDither(levels: 8, pixelSize: size, pattern: pattern), C7OutputQuantization(bitDepth: 12, pattern: pattern)]
            for filter in filters {
                let complete: MTLTexture = try HarbethIO(element: full, filter: filter).output()
                let reference = try ColorMathPixels.read(complete)
                for input in [full, halo] {
                    let origin: Float = input === full ? 0 : 4
                    let region = RegionDither(base: filter, context: [origin, origin, 16, 16, 6, 6, 16, 16])
                    let output = try ColorMathPixels.make(width: 4, height: 4, values: Array(repeating: 99, count: 64), format: .rgba32Float)
                    let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
                    _ = try region.applyAtTexture(form: input, to: output, for: command)
                    command.commit(); command.waitUntilCompleted()
                    var expected: [Float] = []
                    for y in 6..<10 { for x in 6..<10 { expected += reference[(y * 16 + x) * 4..<(y * 16 + x) * 4 + 4] } }
                    XCTAssertEqual(try ColorMathPixels.read(output), expected, "\(filter.modifier) 单元\(size)，输入原点\(origin)")
                }
            }
        } }
    }
}

// 显式绑定因子和区域，包装器强制走同数学的规范像素派发。
private struct RegionDither: C7FilterProtocol {
    let base: any C7FilterProtocol
    let context: [Float]
    var modifier: ModifierEnum { base.modifier }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    var kernelParameterBindings: [KernelParameterBinding] {
        base.factors.enumerated().map { .init(name: "factor.\($0.offset)", index: $0.offset, stage: .compute, value: .float($0.element)) }
        + [.init(name: "region", index: 30, stage: .compute, value: .floatArray(context))]
    }
}
