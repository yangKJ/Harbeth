// 由 Condy 创建于 2026/11/17。
import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class ColorAssociationAndHueTests: XCTestCase {
    func testNeutralAndInvalidParametersKeepFloat32Bits() throws {
        let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.123456, 0.234567, 0.345678, 0.5], format: .rgba32Float)
        for filter: any C7FilterProtocol in [C7ChannelControl(), C7Hue(hue: 0), C7Hue(hue: 360), C7Hue(hue: .nan), C7ColorCorrection(), C7ColorCorrection(levels: .nan, curves: .nan, colorBalance: .nan), C7WhitesBlacks(), C7WhitesBlacks(whites: .nan, blacks: .nan), C7LuminanceAdaptiveContrast(amount: 0), C7LuminanceAdaptiveContrast(amount: .nan), C7Curves(), C7Curves(interpolation: .linear), C7Curves(interpolation: .shapePreserving)] {
            let result: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            XCTAssertEqual(result.c7.rawBytes(maximumBytes: 16), source.c7.rawBytes(maximumBytes: 16), String(describing: filter.modifier))
        }
    }

    func testPointColorMatchesIndependentAssociatedDoubleReference() throws {
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.fixture(width: 17, height: 13, format: format)
            let input = try ColorMathPixels.read(source)
            let filters: [any C7FilterProtocol] = [C7WhitesBlacks(whites: 0.5, blacks: -0.3), C7ColorCorrection(levels: 0.4, curves: -0.5, colorBalance: 0.3), C7LuminanceAdaptiveContrast(amount: 0.7, adaptivity: 0.6), C7FalseColor(fristColor: C7Color(red: 0.8, green: 0.1, blue: 0.2, alpha: 1), secondColor: C7Color(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))]
            for (kind, filter) in filters.enumerated() {
                var expected = input
                for i in stride(from: 0, to: input.count, by: 4) {
                    let a = Double(input[i + 3])
                    if a <= 0 { for c in 0..<4 { expected[i + c] = 0 }; continue }
                    let rgb = (0..<3).map { Double(input[i + $0]) / a }
                    let l = rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722
                    let w = 0.5 * smooth((l - 0.5) / 0.5) * 0.45, b = -0.3 * (1 - smooth(l / 0.5)) * 0.45
                    let contrast = 1 + 0.7 * (0.5 - (rgb[0] * 0.299 + rgb[1] * 0.587 + rgb[2] * 0.114)) * 4 * 0.6
                    let luminance = rgb[0] * 0.2125 + rgb[1] * 0.7154 + rgb[2] * 0.0721
                    for c in 0..<3 {
                        let value: Double
                        switch kind {
                        case 0: value = (rgb[c] * (1 - w) + w) * (1 + b)
                        case 1:
                            var x = pow(max((rgb[c] - 0.04) / 0.92, 0), 0.88)
                            if x < 0.5 { x = pow(x / 0.5, 1.25) * 0.5 }
                            else if x <= 1 { x = 1 - pow((1 - x) / 0.5, 1.25) * 0.5 }
                            value = x + [0.5, 0.2, -0.3][c] * 0.3 * 0.2
                        case 2: value = (rgb[c] - 0.5) * contrast + 0.5
                        default: value = [0.8, 0.1, 0.2][c] + ([0.2, 0.4, 0.9][c] - [0.8, 0.1, 0.2][c]) * luminance
                        }
                        expected[i + c] = Float(value * a)
                    }
                }
                ColorMathPixels.assertPixels(try pixels(source, filter), expected, format: format)
            }
        }
    }

    func testShapeCurvesNormalizeStraightCGImageAndRetainRawModes() throws {
        let image = try straightImage()
        let points = [C7Point2D(x: 0, y: 0), .init(x: 0.5, y: 0.25), .init(x: 1, y: 1)]
        let curve = C7Curves(rgbPoints: points, interpolation: .shapePreserving)
        let a = Float(128) / 255, rgb: [Float] = [Float(128) / 255, Float(64) / 255, Float(32) / 255]
        let frame = try ImageNode.cgImage(image).applying(curve).makeFrame(profile: .exportQuality)
        XCTAssertEqual(frame.alphaType, .premultiplied)
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), rgb.map { C7Curves.shapePreservingValue($0, points: points) * a } + [a], format: frame.texture.pixelFormat)
        let edited = try ImageNode.cgImage(image).applying(curve).editing(EditRecipe()).makeFrame(profile: .exportQuality)
        XCTAssertEqual(edited.alphaType, frame.alphaType)
        XCTAssertEqual(try ColorMathPixels.read(edited.texture), try ColorMathPixels.read(frame.texture))
        for mode in [C7Curves.Interpolation.legacy, .linear] {
            let raw = C7Curves(rgbPoints: [.init(x: 0, y: 0.1), .init(x: 1, y: 0.9)], redPoints: [], greenPoints: [], bluePoints: [], interpolation: mode)
            let result = try ImageNode.cgImage(image).applying(raw).makeFrame(profile: .exportQuality)
            XCTAssertEqual(result.alphaType, .nonPremultiplied)
            ColorMathPixels.assertPixels(try ColorMathPixels.read(result.texture), rgb.map { 0.1 + 0.8 * $0 } + [a], format: result.texture.pixelFormat)
        }
    }

    func testTransparentColorFramesContributeNothingOverBlackAndWhite() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try RGBA8ImageBuffer(width: 1, height: 1, bytes: [0, 0, 0, 0], colorSpace: space).makeCGImage()
        for filter: any C7FilterProtocol in [C7WhitesBlacks(blacks: 0.5), C7ColorCorrection(colorBalance: 0.5), C7LuminanceAdaptiveContrast(amount: 1), C7FalseColor(fristColor: .red, secondColor: .blue)] {
            let frame = try ImageNode.cgImage(image).applying(filter).makeFrame(profile: .exportQuality)
            XCTAssertEqual(frame.alphaType, .premultiplied)
            XCTAssertEqual(try ColorMathPixels.read(frame.texture), [0, 0, 0, 0])
            for value: Float in [0, 1] {
                let background = try ColorMathPixels.make(width: 1, height: 1, values: [value, value, value, 1], format: .rgba16Float)
                XCTAssertEqual(try pixels(background, RenderLayerComposite(layerTexture: frame.texture)), [value, value, value, 1])
            }
        }
    }

    func testHueMatchesIndependentDoubleRotationForSDRHDRAndAlpha() throws {
        func half(_ value: Double) -> Double { Double(Float16(value)) }
        let y = [0.299, 0.587, 0.114].map(half), i = [0.595716, -0.274453, -0.321263].map(half), q = [0.211456, -0.522591, 0.31135].map(half)
        let inverse = [[1, 0.9563, 0.6210], [1, -0.2721, -0.6474], [1, -1.1070, 1.7046]].map { $0.map(half) }
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.make(width: 3, height: 1, values: [1000, 0, 0, 1, 0.01, 0.02, 0.04, 0.05, 0, 0, 0, 0], format: format)
            let input = try ColorMathPixels.read(source)
            for degree: Float in [0, 5, 45, 90, 180, 359, 360] {
                var expected = input
                if degree != 0 && degree != 360 {
                    let angle = Double(Degree(value: degree).radians)
                    for p in stride(from: 0, to: input.count, by: 4) {
                        func dot(_ weights: [Double]) -> Double { (0..<3).reduce(0) { $0 + Double(input[p + $1]) * weights[$1] } }
                        let yy = dot(y), ii = dot(i), qq = dot(q)
                        let yiq = [yy, ii * cos(angle) + qq * sin(angle), qq * cos(angle) - ii * sin(angle)]
                        for c in 0..<3 { expected[p + c] = Float((0..<3).reduce(0) { $0 + yiq[$1] * inverse[c][$1] }) }
                    }
                }
                let actual = try pixels(source, C7Hue(hue: degree))
                XCTAssertTrue(actual.allSatisfy(\.isFinite))
                if format == .rgba32Float {
                    for c in actual.indices {
                        let p = c / 4 * 4
                        // YIQ抵消处的舍入界限由输入尺度决定，不能按接近零的输出比例判断。
                        let scale = input[p..<p + 3].map(abs).max() ?? 0
                        XCTAssertEqual(actual[c], expected[c], accuracy: max(0.00002, scale * Float.ulpOfOne * 8))
                    }
                } else { ColorMathPixels.assertPixels(actual, expected, format: format) }
            }
        }
    }

    func testAsyncColorDeliveryMatchesSyncAndKeepsSource() async throws {
        let source = try ColorMathPixels.fixture(width: 17, height: 13, format: .rgba32Float)
        let before = source.c7.rawBytes(maximumBytes: 17 * 13 * 16)
        let filters: [any C7FilterProtocol] = [C7Hue(hue: 45), C7WhitesBlacks(blacks: 0.2), C7ColorCorrection(curves: 0.3), C7Curves(interpolation: .shapePreserving)]
        let sync: MTLTexture = try HarbethIO(element: source, filters: filters).output()
        let async: MTLTexture = try await HarbethIO(element: source, filters: filters).transmitOutput()
        XCTAssertEqual(try ColorMathPixels.read(async), try ColorMathPixels.read(sync))
        let node = ImageNode.texture(source).applying(filters: filters)
        let a = try node.makeFrame(), b = try await node.makeFrameAsync()
        XCTAssertEqual(try ColorMathPixels.read(a.texture), try ColorMathPixels.read(b.texture))
        XCTAssertEqual(source.c7.rawBytes(maximumBytes: 17 * 13 * 16), before)
    }

    private func straightImage() throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral: 128, 64, 32, 128)) as CFData))
        return try XCTUnwrap(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
    private func smooth(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
    private func pixels(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let out: MTLTexture = try HarbethIO(element: source, filter: filter).output(); return try ColorMathPixels.read(out)
    }
}
