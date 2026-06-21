import XCTest
import Metal
import CoreVideo
import CoreMedia
@testable import Harbeth

final class TransitionKernelTests: XCTestCase {

    func testDissolveTransitionRespectsEndpoints() throws {
        let from = try makeTexture(pixel: [255, 0, 0, 255])
        let to = try makeTexture(pixel: [0, 0, 255, 255])

        let start: MTLTexture = try HarbethIO(
            element: from,
            filter: C7DissolveTransition(toTexture: to, progress: 0)
        ).output()
        let end: MTLTexture = try HarbethIO(
            element: from,
            filter: C7DissolveTransition(toTexture: to, progress: 1)
        ).output()

        XCTAssertEqual(try firstPixel(in: start).red, 255)
        XCTAssertEqual(try firstPixel(in: end).blue, 255)
    }

    func testDirectionalTransitionKeepsOutputSizeStable() throws {
        let from = try makeTexture(width: 3, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 3, height: 2, pixel: [0, 255, 0, 255])

        let output: MTLTexture = try HarbethIO(
            element: from,
            filter: C7DirectionalWipeTransition(toTexture: to, progress: 0.5, angleDegrees: 90)
        ).output()

        XCTAssertEqual(output.width, 3)
        XCTAssertEqual(output.height, 2)
    }

    func testLumaAndDisplacementTransitionsReachTargetAtProgressOne() throws {
        let from = try makeTexture(pixel: [255, 0, 0, 255])
        let to = try makeTexture(pixel: [0, 255, 0, 255])
        let aux = try makeTexture(pixel: [255, 255, 255, 255])

        let lumaOutput: MTLTexture = try HarbethIO(
            element: from,
            filter: C7LumaWipeTransition(toTexture: to, lumaTexture: aux, progress: 1)
        ).output()
        let displacementOutput: MTLTexture = try HarbethIO(
            element: from,
            filter: C7DisplacementTransition(toTexture: to, displacementTexture: aux, progress: 1)
        ).output()

        XCTAssertEqual(try firstPixel(in: lumaOutput).green, 255)
        XCTAssertEqual(try firstPixel(in: displacementOutput).green, 255)
    }

    func testTransitionRecipeRendersFrameAndDiagnostics() throws {
        let from = try makeTexture(width: 3, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 3, height: 2, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 1,
            profile: .stablePreview
        )

        let io = HarbethIO(element: from, filters: [])
        let frame = try io.renderTransitionFrame(recipe, metadata: ["path": "transition"])
        let diagnostics = try io.renderTransitionDiagnostics(recipe)

        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.size.width, 3)
        XCTAssertEqual(frame.size.height, 2)
        XCTAssertEqual(frame.metadata["path"], "transition")
        XCTAssertEqual(try firstPixel(in: frame.texture).blue, 255)
        XCTAssertEqual(diagnostics.stageCount, diagnostics.stages.count)
        XCTAssertEqual(diagnostics.stages.first?.stageKind, .compute)
        XCTAssertEqual(diagnostics.outputSize, C7Size(width: 3, height: 2))
    }

    func testTransitionRecipeClampsProgressAndKeepsDefaultsStable() throws {
        let from = try makeTexture(pixel: [255, 0, 0, 255])
        let to = try makeTexture(pixel: [0, 0, 255, 255])

        let low = TransitionRecipe(from: .texture(from), to: .texture(to), kernel: .dissolve, progress: -1)
        let high = TransitionRecipe(from: .texture(from), to: .texture(to), kernel: .dissolve, progress: 2)

        XCTAssertEqual(low.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(high.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(low.profile, .stablePreview)
        XCTAssertEqual(low.derivative.name, RenderProfile.stablePreview.defaultDerivativeSpec.name)
    }

    func testTransitionRecipeMidpointDiagnosticsExposeTransitionSource() throws {
        let from = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 255, 0, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .directionalWipe(angleDegrees: 45, softness: 0.05),
            progress: 0.5
        )

        let diagnostics = try HarbethIO(element: from, filters: []).renderTransitionDiagnostics(recipe)

        XCTAssertEqual(diagnostics.compilationSource, .transition)
        XCTAssertTrue(diagnostics.containsTransitionKernel)
        XCTAssertFalse(diagnostics.containsLocalEffectComposite)
        XCTAssertEqual(diagnostics.stages.first?.containsTransitionKernel, true)
    }

    func testTransitionDiagnosticsTracksDualInputConversions() throws {
        var fromBuffer: CVPixelBuffer?
        var toBuffer: CVPixelBuffer?
        let fromAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                fromAttributes as CFDictionary,
                &fromBuffer
            ),
            kCVReturnSuccess
        )
        let toAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                toAttributes as CFDictionary,
                &toBuffer
            ),
            kCVReturnSuccess
        )
        guard let fromBuffer,
              let toBuffer,
              let fromSample = fromBuffer.c7.toCMSampleBuffer(),
              let toSample = toBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffers.")
            return
        }

        let recipe = TransitionRecipe(
            from: .sampleBuffer(fromSample),
            to: .sampleBuffer(toSample),
            kernel: .directionalWipe(angleDegrees: 45, softness: 0.05),
            progress: 0.5
        )

        let diagnostics = try HarbethIO(element: fromSample, filters: []).renderTransitionDiagnostics(recipe)

        XCTAssertEqual(diagnostics.inputColorConversionCount, 2)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 2)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.sourceKind, "sampleBuffer")
        XCTAssertTrue(diagnostics.summary.contains("origin=sampleBuffer"))
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=2"))
    }

    private func makeTexture(width: Int = 1, height: Int = 1, pixel: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create texture.")
            throw HarbethError.makeTexture
        }
        let row = Array(repeating: pixel, count: width).flatMap { $0 }
        let bytes = Array(repeating: row, count: height).flatMap { $0 }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}
