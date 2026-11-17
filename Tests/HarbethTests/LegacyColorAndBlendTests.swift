// 由 Condy 创建于 2026/11/17。
import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class LegacyColorAndBlendTests: XCTestCase {
    func testNeutralEndpointsPreserveFloat32AndRepresentableHDR() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let source = try ColorMathPixels.make(width: 2, height: 1, values: [65504,65504,65504,1, 0.123456,0.234567,0.345678,0.5], format: format)
            for filter: any C7FilterProtocol in [C7HSL(), C7Monochrome(intensity: 0), C7ColorRGBA(), C7HighlightShadowTint(), C7Monochrome(intensity: .nan), C7HSL(hue: .nan, saturation: .nan, lightness: .nan)] {
                let result: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                XCTAssertEqual(result.c7.rawBytes(maximumBytes: 32), source.c7.rawBytes(maximumBytes: 32), String(describing: filter.modifier))
            }
        }
    }

    func testNonlinearColorEquationsMatchIndependentDoubleReference() throws {
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.fixture(width: 17, height: 13, format: format), input = try ColorMathPixels.read(source)
            let filters: [any C7FilterProtocol] = [C7HSL(hue: 35, saturation: -0.2, lightness: 0.1), C7Monochrome(red: 0.8, green: 0.3, blue: 0.1, intensity: 0.6), C7HighlightShadowTint(highlights: 0.6, highlightsColor: C7Color(red: 0.1, green: 0.3, blue: 0.7, alpha: 1), shadows: 0.4, shadowsColor: C7Color(red: 0.8, green: 0.2, blue: 0.1, alpha: 1))]
            for (kind, filter) in filters.enumerated() {
                var expected = input
                for i in stride(from: 0, to: input.count, by: 4) {
                    let a = Double(input[i + 3])
                    if a == 0 { for c in 0..<4 { expected[i + c] = 0 }; continue }
                    let rgb = (0..<3).map { Double(input[i + $0]) / a }
                    let l = rgb[0] * 0.2125 + rgb[1] * 0.7154 + rgb[2] * 0.0721
                    let hsl = hslReference(rgb)
                    for c in 0..<3 {
                        let value: Double
                        if kind == 0 { value = hsl[c] }
                        else if kind == 1 {
                            let tint = [0.8, 0.3, 0.1][c]
                            let mapped = l < 0.5 ? 2 * l * tint : 1 - 2 * (1 - l) * (1 - tint)
                            value = rgb[c] * 0.4 + mapped * 0.6
                        } else {
                            let s = [0.8,0.2,0.1][c], h = [0.1,0.3,0.7][c]
                            let shadow = rgb[c] * 0.6 + max(rgb[c], s * (1 - l) + rgb[c] * l) * 0.4
                            let highlight = rgb[c] * 0.4 + min(shadow, shadow * (1 - l) + h * l) * 0.6
                            value = shadow * (1 - l) + highlight * l
                        }
                        expected[i + c] = Float(value * a)
                    }
                }
                ColorMathPixels.assertPixels(try pixels(source, filter), expected, format: format)
            }
        }
    }

    func testTransparentFramesContributeNoColorAndChromaChangesOpaqueMetadata() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let clear = try RGBA8ImageBuffer(width: 1, height: 1, bytes: [0,0,0,0], colorSpace: space).makeCGImage()
        for filter: any C7FilterProtocol in [C7HSL(lightness: 0.2), C7HighlightShadowTint(shadows: 0.5, shadowsColor: .red), C7Monochrome(intensity: 1)] {
            let frame = try ImageNode.cgImage(clear).applying(filter).makeFrame()
            XCTAssertEqual(frame.alphaType, .premultiplied)
            XCTAssertEqual(try ColorMathPixels.read(frame.texture), [0,0,0,0])
            for v: Float in [0,1] {
                let bg = try pixel([v,v,v,1], .rgba16Float)
                XCTAssertEqual(try pixels(bg, RenderLayerComposite(layerTexture: frame.texture)), [v,v,v,1])
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral:255,255,255,255)) as CFData))
        let white = try XCTUnwrap(CGImage(width:1,height:1,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:4,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent))
        let keyed = try ImageNode.cgImage(white).applying(C7BlendChromaKey()).makeFrame()
        XCTAssertEqual(keyed.alphaType, .premultiplied)
        XCTAssertEqual(try ColorMathPixels.read(keyed.texture), [0,0,0,0])
    }

    func testMultiplicativeTintKeepsOriginalAlphaAndFloat32Weight() throws {
        let source = try pixel([0.123456,0.234567,0.345678,0.5], .rgba32Float)
        let p = try ColorMathPixels.read(source), tint: [Float] = [0.2,0.4,0.6]
        let result = try pixels(source, C7ColorRGBA(color: C7Color(red:0.2,green:0.4,blue:0.6,alpha:0), intensity:0.123456))
        let expected = (0..<3).map { p[$0] * (1 + (tint[$0] - 1) * 0.123456) } + [p[3]]
        ColorMathPixels.assertPixels(result, expected, format: .rgba32Float)
    }

    func testNeutralPathsRoundWhenDestinationFormatChanges() throws {
        let source = try pixel([0.123456,0.234567,0.345678,0.5], .rgba32Float)
        let clear = try pixel([0,0,0,0], .rgba16Float)
        var key = C7BlendChromaKey(); key.intensity = 0
        let outside = try C7TextureOverlay(texture: clear, rect: .init(x:2,y:0,width:1,height:1))
        let expected = try ColorMathPixels.read(source).map { Float(Float16($0)) }
        for f: any C7FilterProtocol in [C7HSL(), C7Monochrome(intensity:0), C7ColorRGBA(), C7HighlightShadowTint(), key, C7ColorBurnEnhancedBlend(with:clear), outside] {
            let output = try pixel([0,0,0,0], .rgba16Float), command = try XCTUnwrap(source.device.makeCommandQueue()?.makeCommandBuffer())
            _ = try f.applyAtTexture(form:source,to:output,for:command)
            command.commit(); command.waitUntilCompleted()
            XCTAssertEqual(try ColorMathPixels.read(output), expected, String(describing:f.modifier))
        }
    }

    func testEnhancedBurnKeepsBackgroundCoverageAndUsesForegroundAlpha() throws {
        for format in ColorMathPixels.formats {
            let source = try pixel([0.2,0.1,0.3,0.5], format), layer = try pixel([0.225,0.125,0.05,0.25], format)
            let s = try ColorMathPixels.read(source), f = try ColorMathPixels.read(layer)
            for strength: Float in [0.1,1,2] { for t: Float in [0,0.4,1] {
                let eps = Double(Float(Float16(0.0001))), weight = Double(t * f[3])
                var expected = s
                for c in 0..<3 {
                    let b = Double(s[c] / s[3]), top = Double(f[c] / f[3])
                    let mapped = 1 - min(1, (1 - b) / max(top * Double(strength), eps))
                    expected[c] = Float((b * (1 - weight) + mapped * weight) * Double(s[3]))
                }
                ColorMathPixels.assertPixels(try pixels(source, C7ColorBurnEnhancedBlend(with: layer, strength: strength, intensity: t)), expected, format: format)
            } }
            let clear = try pixel([0,0,0,0], format)
            XCTAssertEqual(try pixels(source, C7ColorBurnEnhancedBlend(with: clear)), s)
            XCTAssertEqual(try pixels(source, C7ColorBurnEnhancedBlend(with: nil)), s)
            XCTAssertEqual(try pixels(clear, C7ColorBurnEnhancedBlend(with: layer, strength: 2)), [0,0,0,0])
        }
    }

    func testSingleInputChromaUsesStraightColorAndOriginalParameterABI() throws {
        for format in ColorMathPixels.formats { for a: Float in [0,0.00001,0.05,0.25,1] {
            let green = try pixel([0,a,0,a], format)
            XCTAssertEqual(try pixels(green, C7BlendChromaKey(threshold: 0.1, smoothing: 0.1, color: .green)), [0,0,0,0])
            XCTAssertEqual(try pixels(green, C7BlendChromaKey(threshold: 0, smoothing: 0, color: .green)), [0,0,0,0])
            var f = C7BlendChromaKey(color: .green); f.intensity = 0
            XCTAssertEqual(try pixels(green, f), try ColorMathPixels.read(green))
        } }
        let f = C7BlendChromaKey()
        XCTAssertTrue(f.otherInputTextures.isEmpty)
        XCTAssertEqual(f.kernelParameterBindings.map(\.index), [0,1,2])
        XCTAssertEqual(f.kernelParameterBindings.map { $0.value.argumentDataType }, [.float2,.float3,.float])
    }

    func testOverlayNormalizesStraightSourceAndPreservesRectCrop() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral:255,0,0,64)) as CFData))
        let image = try XCTUnwrap(CGImage(width:1,height:1,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:4,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent))
        let layer = try pixel([0,0,0.5,0.5], .rgba16Float), filter = try C7TextureOverlay(texture: layer, rect: .init(x:0,y:0,width:1,height:1))
        let frame = try ImageNode.cgImage(image).applying(filter).makeFrame(profile: .exportQuality), a = Float(64) / 255
        XCTAssertEqual(frame.alphaType, .premultiplied)
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), [a * 0.5,0,0.5,0.5 + a * 0.5], format: frame.texture.pixelFormat)
        let source = try ColorMathPixels.fixture(width: 17, height: 13, format: .rgba32Float)
        let outside = try C7TextureOverlay(texture: layer, rect: .init(x:2,y:0,width:1,height:1))
        XCTAssertEqual(try pixels(source, outside), try ColorMathPixels.read(source))
    }

    func testAsyncLegacyColorsAndBlendsKeepSourceAndMatchSync() async throws {
        let source = try ColorMathPixels.fixture(width: 17, height: 13, format: .rgba16Float), before = source.c7.rawBytes(maximumBytes:17*13*8)
        let filters: [any C7FilterProtocol] = [C7HSL(hue: 30), C7Monochrome(intensity: 0.4), C7HighlightShadowTint(shadows: 0.2, shadowsColor: .red), C7ColorBurnEnhancedBlend(with: source, strength: 1.4)]
        let a: MTLTexture = try HarbethIO(element: source, filters: filters).output(), b: MTLTexture = try await HarbethIO(element: source, filters: filters).transmitOutput()
        XCTAssertEqual(try ColorMathPixels.read(a), try ColorMathPixels.read(b))
        let node = ImageNode.texture(source).applying(filters: filters)
        let x = try node.makeFrame(), y = try await node.makeFrameAsync()
        XCTAssertEqual(try ColorMathPixels.read(x.texture), try ColorMathPixels.read(y.texture))
        XCTAssertEqual(source.c7.rawBytes(maximumBytes:17*13*8), before)
    }

    private func hslReference(_ rgb: [Double]) -> [Double] {
        let high = rgb.max()!, low = rgb.min()!, delta = high - low
        var l = (high + low) / 2, s = delta == 0 ? 0 : delta / (1 - abs(2 * l - 1)), h: Double = 0
        if delta > 0 {
            if high == rgb[0] { h = ((rgb[1] - rgb[2]) / delta).truncatingRemainder(dividingBy: 6) * 60 }
            else if high == rgb[1] { h = ((rgb[2] - rgb[0]) / delta + 2) * 60 }
            else { h = ((rgb[0] - rgb[1]) / delta + 4) * 60 }
        }
        h = (h + 35 + 360).truncatingRemainder(dividingBy: 360); s = min(max(s - 0.2,0),1); l = min(max(l + 0.1,0),1)
        let c = (1 - abs(2 * l - 1)) * s, x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1)), m = l - c / 2
        let table = [[c,x,0],[x,c,0],[0,c,x],[0,x,c],[x,0,c],[c,0,x]]
        return table[min(Int(h / 60),5)].map { $0 + m }
    }
    private func pixel(_ p: [Float], _ format: MTLPixelFormat) throws -> MTLTexture { try ColorMathPixels.make(width:1,height:1,values:p,format:format) }
    private func pixels(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let out: MTLTexture = try HarbethIO(element: source, filter: filter).output(); return try ColorMathPixels.read(out)
    }
}
