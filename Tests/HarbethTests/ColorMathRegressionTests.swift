// 由 Condy 创建于 2026/11/17。独立数学参考、关联 Alpha 与两种融合路径。
import XCTest
import Metal
import CoreGraphics
@testable import Harbeth

final class ColorMathRegressionTests: XCTestCase {
    func testDefaultsAndInvalidNeutralParametersKeepFloat32Bits() throws {
        let source = try ColorMathPixels.make(width: 3, height: 1, values: [20000.001, 30000.002, -2.1, 1, 0.013, 0.027, 0.011, 0.05, 0, 0, 0, 0], format: .rgba32Float)
        let bytes = source.c7.rawBytes(maximumBytes: 48)
        let filters: [any C7FilterProtocol] = [C7Brightness(), C7Contrast(), C7Saturation(), C7Exposure(), C7Gamma(), C7Opacity(),
            C7Warmth(), C7Vibrance(), C7Temperature(), C7Temperature(temperature: 1, tint: 1, colorShift: 1, intensity: 0),
            C7WhiteBalance(), C7ColorBalanceEnhanced(), C7Brightness(brightness: .nan), C7Gamma(gamma: .nan),
            C7Gamma(gamma: -1), C7Vibrance(vibrance: .nan), C7WhiteBalance(temperature: .nan, tint: .nan)]
        for filter in filters {
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: 48), bytes, String(describing: filter))
        }
    }

    func testPointColorMathMatchesIndependentDoubleReferenceAcrossStorage() throws {
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.fixture(width: 17, height: 13, format: format)
            let input = try ColorMathPixels.read(source)
            let filters: [any C7FilterProtocol] = [C7Brightness(brightness: 0.12), C7Contrast(contrast: 0.7), C7Saturation(saturation: 0.4),
                C7Exposure(exposure: 0.5), C7Gamma(gamma: 0), C7Gamma(gamma: 2), C7Opacity(opacity: 0), C7Opacity(opacity: 0.4),
                C7Warmth(warmth: 0.5), C7Posterize(levels: 10), C7Vibrance(vibrance: 0.5)]
            for (kind, filter) in filters.enumerated() {
                let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                var expected = input
                for i in stride(from: 0, to: input.count, by: 4) {
                    let p = Array(input[i..<i + 4]).map(Double.init), a = p[3]
                    if a <= 0 { for c in 0..<4 { expected[i + c] = 0 }; continue }
                    let rgb = p.prefix(3).map { $0 / a }
                    let average = rgb.reduce(0, +) / 3, maximum = rgb.max()!
                    for c in 0..<3 {
                        let x = p[c], straight = rgb[c]
                        let value: Double
                        switch kind {
                        case 0: value = x + Double(Float(0.12)) * a
                        case 1: value = 0.5 * a + (x - 0.5 * a) * Double(Float(0.7))
                        case 2: let gray = p[0] * 0.2125 + p[1] * 0.7154 + p[2] * 0.0721; value = x + (gray - x) * (1 - Double(Float(0.4)))
                        case 3: value = x * pow(2, 0.5)
                        case 4: value = a
                        case 5: value = pow(straight, 2) * a
                        case 6: value = 0
                        case 7: value = x * Double(Float(0.4))
                        case 8: value = x + [0.3, 0.2, -0.2][c] * 0.5 * a
                        case 9: value = floor(straight * 10 + 0.5) / 10 * a
                        default: value = (straight + (maximum - straight) * (maximum - average) * -1.5) * a
                        }
                        expected[i + c] = Float(value)
                    }
                    expected[i + 3] = kind == 6 ? 0 : kind == 7 ? Float(a * Double(Float(0.4))) : Float(a)
                }
                ColorMathPixels.assertPixels(try ColorMathPixels.read(output), expected, format: format)
            }
        }
    }

    func testPublicFramesAndBothFusionKernelsDoNotContributeTransparentColor() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let clear = try RGBA8ImageBuffer(width: 1, height: 1, bytes: [0, 0, 0, 0], colorSpace: space).makeCGImage()
        let opaque = try RGBA8ImageBuffer(width: 1, height: 1, bytes: [128, 64, 32, 255], colorSpace: space).makeCGImage()
        let filters: [any C7FilterProtocol] = [C7Gamma(gamma: 0), C7Brightness(brightness: 0.25), C7Contrast(contrast: 0.5), C7Warmth(warmth: 0.5),
            C7Opacity(opacity: 0), ForcedPointFusion(operations: [.init(kind: .gamma, value: 0), .init(kind: .opacity, value: 0)], specialized: false),
            ForcedPointFusion(operations: [.init(kind: .gamma, value: 0), .init(kind: .opacity, value: 0)], specialized: true)]
        for filter in filters {
            let image = filter is C7Opacity ? opaque : clear
            let frame = try ImageNode.cgImage(image).applying(filter).makeFrame(profile: .exportQuality)
            XCTAssertEqual(frame.alphaType, .premultiplied)
            XCTAssertTrue(try ColorMathPixels.read(frame.texture).allSatisfy { $0 == 0 })
            let black = try ColorMathPixels.make(width: 1, height: 1, values: [0, 0, 0, 1], format: .rgba16Float)
            let over: MTLTexture = try HarbethIO(element: black, filter: RenderLayerComposite(layerTexture: frame.texture)).output()
            XCTAssertEqual(try ColorMathPixels.read(over), [0, 0, 0, 1])
        }
    }

    func testExplicitFrameEncodingNormalizesStraightAndOpaqueSources() throws {
        for alphaType in [AlphaType.nonPremultiplied, .premultiplied, .alphaIsOne] {
            let a: Float = alphaType == .alphaIsOne ? 1 : 0.25
            let scale: Float = alphaType == .premultiplied ? a : 1
            let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.5 * scale, 0.25 * scale, 0.75 * scale, a], format: .rgba32Float)
            let io = HarbethIO(element: source, filter: C7Gamma(gamma: 2))
            let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
            let frame = try io.encodeFrame(into: command, inputColorSpace: .extendedLinearSRGB, workingColorSpace: .extendedLinearSRGB, alphaType: alphaType)
            command.commit(); command.waitUntilCompleted()
            ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), [0.25 * a, 0.0625 * a, 0.5625 * a, a], format: frame.texture.pixelFormat)
            XCTAssertEqual(frame.alphaType, alphaType == .alphaIsOne ? .alphaIsOne : .premultiplied)
        }
    }

    func testStraightCGImageSourceMatchesAssociatedGammaMath() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let bytes = Data([UInt8](arrayLiteral: 128, 64, 32, 128))
        let provider = try XCTUnwrap(CGDataProvider(data: bytes as CFData))
        let image = try XCTUnwrap(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
            space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let base = ImageNode.cgImage(image).applying(C7Gamma(gamma: 2))
        let frame = try base.makeFrame(profile: .exportQuality)
        let a = Float(128) / 255
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), [a * a * a, pow(Float(64) / 255, 2) * a, pow(Float(32) / 255, 2) * a, a], format: frame.texture.pixelFormat)
        let edited = try base.editing(EditRecipe()).makeFrame(profile: .exportQuality)
        ColorMathPixels.assertPixels(try ColorMathPixels.read(edited.texture), try ColorMathPixels.read(frame.texture), format: edited.texture.pixelFormat)
        XCTAssertEqual(edited.alphaType, frame.alphaType)
    }

    func testStraightSourceLocalEffectNormalizesBackgroundBeforeBlending() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral: 128, 64, 32, 128)) as CFData))
        let image = try XCTUnwrap(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let a = Float(128) / 255, straight: [Float] = [Float(128) / 255, Float(64) / 255, Float(32) / 255]
        for coverage: Float in [0.5, 1] {
            let mask = try MaskDescriptor(texture: ColorMathPixels.make(width: 1, height: 1, values: [coverage, 0, 0, 1], format: .rgba16Float), component: .red)
            let effect = LocalEffectRecipe(filters: [C7Gamma(gamma: 2)], mask: mask)
            let frame = try ImageNode.cgImage(image).editing(EditRecipe(localEffects: [effect])).makeFrame(profile: .exportQuality)
            let expected = straight.map { ($0 * (1 - coverage) + $0 * $0 * coverage) * a } + [a]
            ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), expected, format: frame.texture.pixelFormat)
            XCTAssertEqual(frame.alphaType, .premultiplied)
        }
    }

    func testEmptyEditKeepsChangedAlphaMetadataAndPixels() throws {
        let input = try ColorMathPixels.make(width: 2, height: 2, values: Array(repeating: [Float](arrayLiteral: 0.2, 0.3, 0.4, 1), count: 4).flatMap { $0 }, format: .rgba16Float)
        let node = ImageNode.texture(input).applying(C7Opacity(opacity: 0))
        let direct = try node.makeFrame(), edited = try node.editing(EditRecipe()).makeFrame()
        XCTAssertEqual(direct.alphaType, .premultiplied)
        XCTAssertEqual(edited.alphaType, direct.alphaType)
        XCTAssertEqual(try ColorMathPixels.read(direct.texture), try ColorMathPixels.read(edited.texture))
    }

    func testFusionMatchesEveryStandaloneStorageBoundary() throws {
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.fixture(width: 17, height: 13, format: format)
            let operations: [C7FusedPointOperations.Operation] = [.init(kind: .brightness, value: 0.08), .init(kind: .contrast, value: 1.15),
                .init(kind: .saturation, value: 0.85), .init(kind: .exposure, value: 0.25), .init(kind: .gamma, value: 1.1), .init(kind: .opacity, value: 0.7)]
            let filters: [any C7FilterProtocol] = [C7Brightness(brightness: 0.08), C7Contrast(contrast: 1.15), C7Saturation(saturation: 0.85),
                C7Exposure(exposure: 0.25), C7Gamma(gamma: 1.1), C7Opacity(opacity: 0.7)]
            var expected = source
            for filter in filters { expected = try HarbethIO(element: expected, filter: filter).output() }
            for specialized in [false, true] {
                let actual: MTLTexture = try HarbethIO(element: source, filter: ForcedPointFusion(operations: operations, specialized: specialized)).output()
                ColorMathPixels.assertPixels(try ColorMathPixels.read(actual), try ColorMathPixels.read(expected), format: format)
            }
        }
    }

    func testVibranceGrayHDRAndTemperatureNeutralAreFiniteAndExact() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for value: Float in [-20000, 20000, 30000, 65504] {
                let source = try ColorMathPixels.make(width: 3, height: 1, values: Array(repeating: [value, value, value, 1], count: 3).flatMap { $0 }, format: format)
                for filter: any C7FilterProtocol in [C7Vibrance(vibrance: 0.5), C7Vibrance(), C7WhiteBalance(), C7Temperature(),
                    C7Temperature(temperature: 1, tint: 1, colorShift: 1, intensity: 0)] {
                    let out: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                    XCTAssertEqual(out.c7.rawBytes(maximumBytes: 48), source.c7.rawBytes(maximumBytes: 48))
                }
            }
        }
    }

    func testSignedTemperatureHasNeutralZeroAndSymmetricWarmDirection() throws {
        let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.5, 0.5, 0.5, 1], format: .rgba32Float)
        for t: Float in [-1, 0, 1] {
            let output: MTLTexture = try HarbethIO(element: source, filter: C7Temperature(temperature: t)).output()
            let actual = try ColorMathPixels.read(output)
            for c in 0..<3 { XCTAssertEqual(actual[c], 0.5 + ([Float](arrayLiteral: 0.93, 0.54, 0)[c] - 0.5) * t, accuracy: 0.00001) }
        }
    }

    func testBalanceEmptyMarkersAndNonnegativeZonesUseStraightLuminance() throws {
        let adjustment = C7Color(red: 0.625, green: 0.5, blue: 0.5, alpha: 1)
        func smooth(_ lo: Double, _ hi: Double, _ x: Double) -> Double { let t = min(max((x - lo) / (hi - lo), 0), 1); return t * t * (3 - 2 * t) }
        for alpha: Float in [0, 0.25, 1] { for value: Float in [0, 0.05, 0.5, 0.95, 1] {
            let source = try ColorMathPixels.make(width: 1, height: 1, values: [value * alpha, value * alpha, value * alpha, alpha], format: .rgba32Float)
            let neutral: MTLTexture = try HarbethIO(element: source, filter: C7ColorBalanceEnhanced()).output()
            XCTAssertEqual(try ColorMathPixels.read(neutral), try ColorMathPixels.read(source))
            for zone in 0..<3 {
                let f = C7ColorBalanceEnhanced(shadows: zone == 0 ? adjustment : .zero, midtones: zone == 1 ? adjustment : .zero, highlights: zone == 2 ? adjustment : .zero)
                let out: MTLTexture = try HarbethIO(element: source, filter: f).output()
                let shadow = 1 - smooth(0, 0.3, Double(value)), high = smooth(0.7, 1, Double(value))
                let weight = [shadow, 1 - shadow - high, high][zone]
                let expected: [Float] = [(value + 0.25 * Float(weight)) * alpha, value * alpha, value * alpha, alpha]
                ColorMathPixels.assertPixels(try ColorMathPixels.read(out), expected, format: .rgba32Float)
            }
        } }
    }

    func testBothLevelsRoutesShareDomainsAndPreserveCoverage() throws {
        let gray = C7Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let input = try ColorMathPixels.fixture(width: 17, height: 13, format: .rgba16Float)
        let cases: [(C7Levels, C7LevelsAdjustment)] = [(C7Levels(), C7LevelsAdjustment()),
            (C7Levels(minimum: gray, maximum: gray), C7LevelsAdjustment(inputBlack: .init(repeating: 0.5), inputWhite: .init(repeating: 0.5))),
            (C7Levels(middle: .black), C7LevelsAdjustment(gamma: .zero)),
            (C7Levels(minOutput: .white, maxOutput: .black), C7LevelsAdjustment(outputBlack: .init(repeating: 1), outputWhite: .zero))]
        let source = try ColorMathPixels.read(input)
        for (legacy, numeric) in cases {
            let a: MTLTexture = try HarbethIO(element: input, filter: legacy).output(), b: MTLTexture = try HarbethIO(element: input, filter: numeric).output()
            let values = try ColorMathPixels.read(a)
            XCTAssertEqual(values, try ColorMathPixels.read(b))
            for i in stride(from: 0, to: values.count, by: 4) {
                XCTAssertTrue(values[i..<i + 4].allSatisfy(\.isFinite)); XCTAssertEqual(values[i + 3], source[i + 3])
                for c in 0..<3 { XCTAssertLessThanOrEqual(values[i + c], values[i + 3] + 0.001); XCTAssertGreaterThanOrEqual(values[i + c], 0) }
            }
        }
    }

    func testColorInterpolationEndpointsMidpointAndRandomRange() {
        let start = C7Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.3), end = C7Color(red: 0.8, green: 0.6, blue: 0.4, alpha: 0.9)
        XCTAssertEqual(start.c7.linearInterpolation(directionColor: end, rate: 0), start)
        XCTAssertEqual(start.c7.linearInterpolation(directionColor: end, rate: 1), end)
        XCTAssertEqual(start.c7.linearInterpolation(directionColor: end, rate: .nan), start)
        let middle = start.c7.linearInterpolation(directionColor: end, rate: 0.5).c7.toSIMD4()
        for c in 0..<4 { XCTAssertEqual(middle[c], [Float](arrayLiteral: 0.5, 0.5, 0.5, 0.6)[c], accuracy: 0.00001) }
        let colors = (0..<100).map { _ in C7Color.random.c7.toSIMD4() }
        XCTAssertGreaterThan(Set(colors.map { String(describing: $0) }).count, 1)
        XCTAssertTrue(colors.allSatisfy { v in (0..<3).allSatisfy { (0...1).contains(v[$0]) } && v.w == 1 })
    }
}

private struct ForcedPointFusion: C7FilterProtocol {
    let operations: [C7FusedPointOperations.Operation]
    let specialized: Bool
    var base: C7FusedPointOperations { .init(operations: operations) }
    var modifier: ModifierEnum { .compute(kernel: specialized ? "C7FusedPointOperationsSpecialized" : "C7FusedPointOperations") }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] { specialized ? base.computeKernelFunctionConstants : [] }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    var kernelOutputContract: RenderOutputContract { base.kernelOutputContract }
}

// 数值上传和读回明确处理 BGRA，参考值来自实际存储精度。
enum ColorMathPixels {
    static let formats: [MTLPixelFormat] = [.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float]
    static func make(width: Int, height: Int, values: [Float], format: MTLPixelFormat) throws -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let t = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: d))
        if format == .rgba16Float {
            values.map { Float16($0) }.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        } else if format == .rgba32Float {
            values.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        } else {
            var bytes = values.map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
            if format == .bgra8Unorm { for i in stride(from: 0, to: bytes.count, by: 4) { bytes.swapAt(i, i + 2) } }
            bytes.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        }
        return t
    }
    static func fixture(width: Int, height: Int, format: MTLPixelFormat) throws -> MTLTexture {
        var values: [Float] = []
        for y in 0..<height { for x in 0..<width {
            let a: Float = (x + y) % 7 == 0 ? 0 : (x + y) % 7 == 1 ? 0.05 : (x + y) % 7 == 2 ? 0.25 : 1
            values += [Float((x * 7 + y * 11) % 19) / 19 * a, Float((x * 3 + y * 5) % 17) / 17 * a, Float((x + y) % 13) / 13 * a, a]
        } }
        return try make(width: width, height: height, values: values, format: format)
    }
    static func read(_ texture: MTLTexture) throws -> [Float] {
        let size = texture.pixelFormat == .rgba32Float ? 16 : texture.pixelFormat == .rgba16Float ? 8 : 4
        let bytes = try XCTUnwrap(texture.c7.rawBytes(maximumBytes: texture.width * texture.height * size))
        if size == 4 {
            var values = bytes.map { Float($0) / 255 }
            if texture.pixelFormat == .bgra8Unorm { for i in stride(from: 0, to: values.count, by: 4) { values.swapAt(i, i + 2) } }
            return values
        }
        return bytes.withUnsafeBytes { size == 8 ? $0.bindMemory(to: UInt16.self).map { Float(Float16(bitPattern: $0)) } : Array($0.bindMemory(to: Float.self)) }
    }
    static func assertPixels(_ actual: [Float], _ expected: [Float], format: MTLPixelFormat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for i in actual.indices {
            let value = format == .rgba8Unorm || format == .bgra8Unorm ? (min(max(expected[i], 0), 1) * 255).rounded() / 255 : expected[i]
            let tolerance: Float = format == .rgba32Float ? max(0.00002, abs(value) * 0.000002) : format == .rgba16Float ? max(0.001, abs(value) * 0.001) : 1.1 / 255
            if !actual[i].isFinite || abs(actual[i] - value) > tolerance { XCTFail("分量 \(i)：\(actual[i])，参考 \(value)", file: file, line: line); return }
        }
    }
}
