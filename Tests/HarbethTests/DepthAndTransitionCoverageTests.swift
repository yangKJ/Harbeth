// 由 Condy 创建于 2026/11/17。
import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class DepthAndTransitionCoverageTests: XCTestCase {
    func testDepthBlurMatchesCoverageNormalizedReferenceAndKeepsCentreAlpha() throws {
        let w = 9, h = 5
        let depth = try ColorMathPixels.make(width: w, height: h, values: (0..<w * h).flatMap { i in [Float(i % w == 0 ? 0 : 1), 0, 0, 1] }, format: .rgba32Float)
        let descriptor = DepthLensBlurDescriptor(focusPoint: .init(0.5 / Float(w), 0.5), intensity: 1, focusRange: 0.005, transition: 0.005, blurRadius: 1)
        let offsets: [(Double, Double)] = [(0,0),(1,0),(-1,0),(0.5,0.866),(-0.5,0.866),(0.5,-0.866),(-0.5,-0.866),(2,0),(-2,0),(1,1.732),(-1,1.732),(1,-1.732),(-1,-1.732)]
        for format in ColorMathPixels.formats {
            let source = try ColorMathPixels.fixture(width: w, height: h, format: format), input = try ColorMathPixels.read(source)
            var expected = input
            for y in 0..<h { for x in 1..<w {
                let i = (y * w + x) * 4, a = Double(input[i + 3])
                if a == 0 { for c in 0..<4 { expected[i + c] = 0 }; continue }
                var sum = [Double](repeating: 0, count: 3), coverage: Double = 0
                for (tap, offset) in offsets.enumerated() {
                    let sx = min(max(x + Int(offset.0.rounded()), 0), w - 1), sy = min(max(y + Int(offset.1.rounded()), 0), h - 1)
                    let j = (sy * w + sx) * 4, weight: Double = tap == 0 ? 0.24 : tap < 7 ? 0.10 : 0.026
                    if input[j + 3] > 0 { for c in 0..<3 { sum[c] += Double(input[j + c]) * weight }; coverage += Double(input[j + 3]) * weight }
                }
                for c in 0..<3 { expected[i + c] = Float(sum[c] / coverage * a) }
            } }
            let actual: MTLTexture = try HarbethIO(element: source, filter: C7DepthLensBlur(descriptor: descriptor, depthTexture: depth)).output()
            ColorMathPixels.assertPixels(try ColorMathPixels.read(actual), expected, format: format)
        }
    }

    func testDepthClearCentreAndPositiveTinyCoverageAndIdentityFloat32() throws {
        let depth = try ColorMathPixels.make(width: 5, height: 1, values: [0,0,0,1, 1,0,0,1, 1,0,0,1, 1,0,0,1, 1,0,0,1], format: .rgba32Float)
        let descriptor = DepthLensBlurDescriptor(focusPoint: .init(0.1, 0.5), intensity: 1, focusRange: 0.005, transition: 0.005, blurRadius: 1)
        let source = try ColorMathPixels.make(width: 5, height: 1, values: [1,0,0,1, 1,0,0,1, 0,0,0,0, 1,0,0,1, 1,0,0,1], format: .rgba16Float)
        let result: MTLTexture = try HarbethIO(element: source, filter: C7DepthLensBlur(descriptor: descriptor, depthTexture: depth)).output()
        XCTAssertEqual(Array(try ColorMathPixels.read(result)[8..<12]), [0,0,0,0])
        let black = try ColorMathPixels.make(width: 5, height: 1, values: Array(repeating: [Float](arrayLiteral: 0,0,0,1), count: 5).flatMap { $0 }, format: .rgba16Float)
        let over: MTLTexture = try HarbethIO(element: black, filter: RenderLayerComposite(layerTexture: result)).output()
        XCTAssertEqual(Array(try ColorMathPixels.read(over)[8..<12]), [0,0,0,1])
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let a: Float = 0.000001
            let tiny = try ColorMathPixels.make(width: 5, height: 1, values: Array(repeating: [a, a * 0.5, a * 0.25, a], count: 5).flatMap { $0 }, format: format)
            let output: MTLTexture = try HarbethIO(element: tiny, filter: C7DepthLensBlur(descriptor: descriptor, depthTexture: depth)).output()
            XCTAssertEqual(try ColorMathPixels.read(output), try ColorMathPixels.read(tiny))
        }
        let precise = try ColorMathPixels.make(width: 5, height: 1, values: Array(repeating: [Float](arrayLiteral: 0.123456, 0.234567, 0.345678, 0.5), count: 5).flatMap { $0 }, format: .rgba32Float)
        let identity: MTLTexture = try HarbethIO(element: precise, filter: C7DepthLensBlur(descriptor: .identity, depthTexture: depth)).output()
        XCTAssertEqual(identity.c7.rawBytes(maximumBytes: 80), precise.c7.rawBytes(maximumBytes: 80))
    }

    func testDepthRegionWithHaloMatchesFullCanvasCentre() throws {
        let full = try ColorMathPixels.fixture(width: 9, height: 5, format: .rgba32Float), values = try ColorMathPixels.read(full)
        let depth = try ColorMathPixels.make(width: 9, height: 5, values: (0..<45).flatMap { i in [Float(i % 9 == 0 ? 0 : 1), 0, 0, 1] }, format: .rgba32Float)
        let base = C7DepthLensBlur(descriptor: .init(focusPoint: .init(0.5 / 9, 0.5), intensity: 1, focusRange: 0.005, transition: 0.005, blurRadius: 1), depthTexture: depth)
        let all: MTLTexture = try HarbethIO(element: full, filter: base).output()
        var cropped: [Float] = []
        for y in 0..<5 { for x in 2..<7 { cropped += values[(y * 9 + x) * 4..<(y * 9 + x) * 4 + 4] } }
        let halo = try ColorMathPixels.make(width: 5, height: 5, values: cropped, format: .rgba32Float)
        let output = try ColorMathPixels.make(width: 1, height: 1, values: [99,99,99,99], format: .rgba32Float)
        let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
        _ = try DepthRegion(base: base).applyAtTexture(form: halo, to: output, for: command)
        command.commit(); command.waitUntilCompleted()
        ColorMathPixels.assertPixels(try ColorMathPixels.read(output), Array(try ColorMathPixels.read(all)[88..<92]), format: .rgba32Float)
    }

    func testTransitionsMapTargetAndAuxiliaryPixelCentres() throws {
        let from = try texture(4, [0,0,0,1, 0.25,0,0,1, 0.5,0,0,1, 1,0,0,1])
        let to = try texture(2, [0,0,0,1, 1,0,0,1]), aux = try texture(2, [0,0,0,1, 1,1,1,1])
        let expected: [Float] = [0,0.25,0.75,1]
        let filters: [any C7FilterProtocol] = [DissolveTransition(toTexture: to, progress: 1), DirectionalWipeTransition(toTexture: to, progress: 1), LumaWipeTransition(toTexture: to, lumaTexture: aux, progress: 1), DisplacementTransition(toTexture: to, displacementTexture: aux, progress: 1)]
        for filter in filters {
            let p = try pixels(from, filter)
            for x in 0..<4 { XCTAssertEqual(p[x * 4], expected[x], accuracy: 0.001) }
            XCTAssertFalse(filter.kernelPixelContract.canAutoTile)
        }
        let black = try texture(4, Array(repeating: [Float](arrayLiteral: 0,0,0,1), count: 4).flatMap { $0 }), red = try texture(1, [1,0,0,1])
        let luma = try pixels(black, LumaWipeTransition(toTexture: red, lumaTexture: aux, progress: 0.5, softness: 0.1))
        XCTAssertEqual(stride(from: 0, to: 16, by: 4).map { luma[$0] }, [0,0,1,1])
        let displacement = try texture(2, [0,0.5,0,1, 1,0.5,0,1])
        let moved = try pixels(from, DisplacementTransition(toTexture: try texture(1, [0,0,0,1]), displacementTexture: displacement, progress: 0.5, scale: 2))
        XCTAssertEqual(stride(from: 0, to: 16, by: 4).map { moved[$0] }, [0,0,0.5,0.5])
    }

    func testTransitionInvalidParametersHaveFiniteCanonicalBindingsAndFingerprints() throws {
        let t = try texture(1, [0.2,0.3,0.4,1])
        var directional = DirectionalWipeTransition(toTexture: t, progress: .nan, angleDegrees: .infinity, softness: .nan)
        directional.progress = .nan; directional.angleDegrees = .nan; directional.softness = .nan
        var displaced = DisplacementTransition(toTexture: t, displacementTexture: t, progress: .nan, scale: .infinity)
        displaced.scale = .nan
        var page = PageCurlTransition(toTexture: t, progress: 0.5)
        page.progress = .nan; page.angleDegrees = .infinity; page.radius = .nan; page.shadowStrength = .nan; page.shadowRadius = .nan
        for filter: any C7FilterProtocol in [DissolveTransition(toTexture: t, progress: .nan), directional, LumaWipeTransition(toTexture: t, lumaTexture: t, progress: .nan, softness: .nan), displaced, page] {
            XCTAssertTrue(filter.factors.allSatisfy(\.isFinite))
            XCTAssertEqual(try pixels(t, filter), try ColorMathPixels.read(t))
        }
        XCTAssertEqual(TransitionKernelDescriptor.directionalWipe(angleDegrees: .nan, softness: .nan).fingerprint, TransitionKernelDescriptor.directionalWipe(angleDegrees: 0, softness: 0.02).fingerprint)
        XCTAssertEqual(TransitionKernelDescriptor.displacement(displacementSource: .texture(t), scale: .infinity).fingerprint, TransitionKernelDescriptor.displacement(displacementSource: .texture(t), scale: 0.05).fingerprint)
    }

    func testPublicTransitionNormalizesStraightTargetAndMatchesAsync() async throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral: 128,64,32,128)) as CFData))
        let target = try XCTUnwrap(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let from = try texture(4, Array(repeating: [Float](arrayLiteral: 0,0,0,0), count: 4).flatMap { $0 })
        let node = ImageNode.transition(from: .texture(from), to: .cgImage(target), kernel: .dissolve, progress: 1, profile: .exportQuality)
        let frame = try node.makeFrame(), asyncFrame = try await node.makeFrameAsync()
        XCTAssertEqual(frame.alphaType, .premultiplied)
        let a = Float(128) / 255, expected: [Float] = [a * a, Float(64) / 255 * a, Float(32) / 255 * a, a]
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), Array(repeating: expected, count: 4).flatMap { $0 }, format: frame.texture.pixelFormat)
        XCTAssertEqual(try ColorMathPixels.read(asyncFrame.texture), try ColorMathPixels.read(frame.texture))
    }

    func testRedMonochromeKeepsOpaqueGrayAndDeclaresActualCoverage() throws {
        let source = try texture(1, [0.125,0,0,0.25]), filter = C7RedMonochromeBlur(pixelRadius: 0)
        XCTAssertEqual(filter.kernelPixelContract.outputAlpha, .opaque)
        let frame = try ImageNode.texture(source).applying(filter).makeFrame()
        XCTAssertEqual(frame.alphaType, .alphaIsOne)
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), [0.125,0.125,0.125,1], format: frame.texture.pixelFormat)
    }

    private func texture(_ width: Int, _ values: [Float]) throws -> MTLTexture { try ColorMathPixels.make(width: width, height: 1, values: values, format: .rgba16Float) }
    private func pixels(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let out: MTLTexture = try HarbethIO(element: source, filter: filter).output(); return try ColorMathPixels.read(out)
    }
}

private struct DepthRegion: C7FilterProtocol {
    let base: C7DepthLensBlur
    var modifier: ModifierEnum { base.modifier }
    var otherInputTextures: C7InputTextures { base.otherInputTextures }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings + [.init(name: "region", index: 30, stage: .compute, value: .floatArray([2,0,9,5,4,2,9,5]))] }
}
