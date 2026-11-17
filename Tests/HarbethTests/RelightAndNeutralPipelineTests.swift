// 由 Condy 创建于 2026/11/17。
import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

final class RelightAndNeutralPipelineTests: XCTestCase {
    func testRolloffUsesStraightLuminanceAcrossCoverageAndStorage() throws {
        let depth = try texture([0.5,0,0,1], .rgba32Float)
        let filter = C7SceneRelight(descriptor: try .init(ambient: 2, highlightRolloff: 1), depthTexture: depth)
        for format in ColorMathPixels.formats { for alpha: Float in [0,0.05,0.25,0.5,1] {
            let source = try texture([0.8*alpha,0.6*alpha,0.4*alpha,alpha], format), input = try ColorMathPixels.read(source)
            var expected = input
            if input[3] > 0 {
                let luma = (Double(input[0]) * 0.2126 + Double(input[1]) * 0.7152 + Double(input[2]) * 0.0722) / Double(input[3])
                for c in 0..<3 { expected[c] = Float(Double(input[c]) * (1 + 1 / (1 + luma))) }
            }
            let out: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            ColorMathPixels.assertPixels(try ColorMathPixels.read(out), expected, format: format)
        } }
    }

    func testSceneIdentityPreservesExtendedFloat32AndStraightCGSource() throws {
        let depth = try texture([0.5,0,0,1], .rgba32Float), filter = C7SceneRelight(descriptor: .identity, depthTexture: depth)
        let source = try texture([70000,2000,1,1], .rgba32Float)
        let out: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        XCTAssertEqual(out.c7.rawBytes(maximumBytes:16), source.c7.rawBytes(maximumBytes:16))
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), provider = try XCTUnwrap(CGDataProvider(data: Data([UInt8](arrayLiteral:255,0,0,64)) as CFData))
        let image = try XCTUnwrap(CGImage(width:1,height:1,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:4,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent))
        let frame = try ImageNode.cgImage(image).applying(filter).makeFrame(profile: .exportQuality), alpha = Float(64) / 255
        XCTAssertEqual(frame.alphaType, .premultiplied)
        ColorMathPixels.assertPixels(try ColorMathPixels.read(frame.texture), [alpha,0,0,alpha], format: frame.texture.pixelFormat)
    }

    func testNonFiniteRadiusAndControlsAreSafeDuringPlanningAndEncoding() throws {
        let tone = C7HighlightShadowTone(shadows: .nan, highlights: .nan, midtones: .nan, contrast: .nan, radius: .nan)
        let skin = C7HighPassSkinSmoothing(amount: .nan, radius: .nan, detailThreshold: .nan, detailTransition: .nan, sharpnessFactor: .nan, toneCurveInputMidpoint: .nan, toneCurveOutputMidpoint: .nan)
        let source = try texture([0.1,0.2,0.3,0.5], .rgba32Float)
        for f: any C7FilterPipelineProtocol in [tone, skin] {
            XCTAssertTrue(f.factors.allSatisfy(\.isFinite))
            XCTAssertFalse(f.makeKernelExecutionPlan(inputSize: .init(width:1,height:1)).passes.isEmpty)
            let out: MTLTexture = try HarbethIO(element: source, filter: f).output()
            XCTAssertEqual(out.c7.rawBytes(maximumBytes:16), source.c7.rawBytes(maximumBytes:16))
        }
        var gaussian = MPSGaussianBlur(radius: .nan)
        XCTAssertTrue(gaussian.sigma.isFinite); gaussian.radius = .nan; XCTAssertTrue(gaussian.sigma.isFinite)
    }

    func testNeutralPipelinesHaveNoGuidesAndHandleFormatConversion() throws {
        for f: any C7FilterPipelineProtocol in [C7HighPassSkinSmoothing(amount:0, radius:8, sharpnessFactor:1), C7HighlightShadowTone(radius:30)] {
            XCTAssertTrue(f.pipelineFilters.isEmpty)
            XCTAssertEqual(f.pipelineOtherInputCount, 0)
            for format in ColorMathPixels.formats {
                let source = try ColorMathPixels.fixture(width:17,height:13,format:format)
                let out: MTLTexture = try HarbethIO(element: source, filter: f).output()
                XCTAssertEqual(out.c7.rawBytes(maximumBytes:17*13*16), source.c7.rawBytes(maximumBytes:17*13*16))
            }
            let source = try texture([0.123456,0.234567,0.345678,0.5], .rgba32Float), destination = try texture([0,0,0,0], .rgba16Float)
            let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
            _ = try f.applyAtTexture(form: source, to: destination, for: command)
            command.commit(); command.waitUntilCompleted()
            let expected = try ColorMathPixels.read(source).map { Float(Float16($0)) }
            XCTAssertEqual(try ColorMathPixels.read(destination), expected)
        }
    }

    func testMutableSkinParametersInvalidateNeutralPreparedRoute() throws {
        let source = try ColorMathPixels.fixture(width:17,height:13,format:.rgba16Float), before = source.c7.rawBytes(maximumBytes:17*13*8)
        let skin = C7HighPassSkinSmoothing(amount:0, radius:2)
        let io = HarbethIO(element: source, filter: skin)
        let zero: MTLTexture = try io.output()
        skin.amount = 0.8
        let active: MTLTexture = try io.output()
        XCTAssertNotEqual(active.c7.rawBytes(maximumBytes:17*13*8), before)
        skin.amount = 0
        let restored: MTLTexture = try io.output()
        XCTAssertEqual(restored.c7.rawBytes(maximumBytes:17*13*8), zero.c7.rawBytes(maximumBytes:17*13*8))
        XCTAssertEqual(source.c7.rawBytes(maximumBytes:17*13*8), before)
    }

    func testNeutralPipelineAsyncRoutesKeepOwnershipAndPixels() async throws {
        let source = try ColorMathPixels.fixture(width:17,height:13,format:.rgba32Float), before = source.c7.rawBytes(maximumBytes:17*13*16)
        for f: any C7FilterProtocol in [C7HighPassSkinSmoothing(amount:0), C7HighlightShadowTone()] {
            let out: MTLTexture = try await HarbethIO(element: source, filter: f).transmitOutput()
            XCTAssertEqual(out.c7.rawBytes(maximumBytes:17*13*16), before)
            let node = ImageNode.texture(source).applying(f), a = try node.makeFrame(), b = try await node.makeFrameAsync()
            XCTAssertEqual(try ColorMathPixels.read(a.texture), try ColorMathPixels.read(b.texture))
        }
        XCTAssertEqual(source.c7.rawBytes(maximumBytes:17*13*16), before)
    }

    private func texture(_ values: [Float], _ format: MTLPixelFormat) throws -> MTLTexture {
        try ColorMathPixels.make(width:1,height:1,values:values,format:format)
    }
}
