import XCTest
import Metal
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
