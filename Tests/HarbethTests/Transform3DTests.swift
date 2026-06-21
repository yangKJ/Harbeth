import XCTest
import Metal
import QuartzCore
@testable import Harbeth

final class Transform3DTests: XCTestCase {

    func testTransform3DOriginalViewportPreservesInputSize() {
        let filter = RenderTransform3D(
            transform: CATransform3DMakeRotation(.pi / 2, 0, 0, 1),
            viewportMode: .original
        )

        XCTAssertEqual(filter.resize(input: C7Size(width: 20, height: 10)), C7Size(width: 20, height: 10))
    }

    func testTransform3DMinimumEnclosingViewportSwapsQuarterTurnSize() {
        let filter = RenderTransform3D(
            transform: CATransform3DMakeRotation(.pi / 2, 0, 0, 1),
            viewportMode: .minimumEnclosing
        )

        XCTAssertEqual(filter.resize(input: C7Size(width: 20, height: 10)), C7Size(width: 10, height: 20))
    }

    func testTransform3DIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 180, green: 90, blue: 30, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: RenderTransform3D(transform: CATransform3DIdentity, viewportMode: .original)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 180, accuracy: 2)
        XCTAssertEqual(pixel.green, 90, accuracy: 2)
        XCTAssertEqual(pixel.blue, 30, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testTransform3DPerspectiveOriginalViewportPreservesInputSize() {
        let filter = RenderTransform3D(
            transform: CATransform3DIdentity,
            fieldOfView: .pi / 4,
            viewportMode: .original
        )

        XCTAssertEqual(filter.resize(input: C7Size(width: 20, height: 10)), C7Size(width: 20, height: 10))
    }

    func testTransform3DPerspectiveVerticesCarryProjectedW() {
        let filter = RenderTransform3D(
            transform: CATransform3DMakeRotation(.pi / 8, 0, 1, 0),
            fieldOfView: .pi / 4,
            viewportMode: .original
        )

        let vertices = filter.setupVertices(inputSize: C7Size(width: 20, height: 10)) ?? []
        XCTAssertEqual(vertices.count, 20)
        let ws = stride(from: 2, to: vertices.count, by: 5).map { vertices[$0] }
        XCTAssertTrue(ws.contains(where: { abs($0 - 1) > 0.0001 }))
    }

    func testPerspectiveTransformBuildsNonIdentityProjectionFilter() {
        let perspective = PerspectiveTransform(
            vertical: .pi / 18,
            horizontal: -.pi / 20,
            rotate: .pi / 36,
            scale: 0.96,
            fieldOfView: .pi / 5
        )

        let filter = RenderTransform3D(perspective: perspective, viewportMode: .minimumEnclosing)

        XCTAssertEqual(filter.fieldOfView, .pi / 5, accuracy: 0.0001)
        XCTAssertNotEqual(filter.transform.m11, CATransform3DIdentity.m11, accuracy: 0.0001)
    }

    func testPerspectiveTransformMinimumEnclosingChangesOutputSize() {
        let perspective = PerspectiveTransform(
            vertical: .pi / 12,
            horizontal: 0,
            rotate: 0,
            scale: 1,
            fieldOfView: .pi / 5
        )
        let filter = RenderTransform3D(perspective: perspective, viewportMode: .minimumEnclosing)

        let outputSize = filter.resize(input: C7Size(width: 20, height: 10))
        XCTAssertGreaterThan(outputSize.width, 0)
        XCTAssertGreaterThan(outputSize.height, 0)
        XCTAssertNotEqual(outputSize, C7Size(width: 20, height: 10))
    }

    func testQuadTransformOriginalViewportPreservesInputSize() {
        let filter = RenderQuadTransform(
            quad: .identity,
            viewportMode: .original
        )

        XCTAssertEqual(filter.resize(input: C7Size(width: 20, height: 10)), C7Size(width: 20, height: 10))
    }

    func testQuadTransformMinimumEnclosingExpandsWhenCornerMovesOutward() {
        let filter = RenderQuadTransform(
            quad: .init(
                topLeft: .init(x: -0.2, y: 0),
                topRight: .init(x: 1, y: 0),
                bottomLeft: .init(x: 0, y: 1),
                bottomRight: .init(x: 1, y: 1)
            ),
            viewportMode: .minimumEnclosing
        )

        let outputSize = filter.resize(input: C7Size(width: 20, height: 10))
        XCTAssertGreaterThan(outputSize.width, 20)
        XCTAssertEqual(outputSize.height, 10)
    }

    func testQuadTransformIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 80, green: 140, blue: 220, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: RenderQuadTransform(quad: .identity, viewportMode: .original)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 80, accuracy: 2)
        XCTAssertEqual(pixel.green, 140, accuracy: 2)
        XCTAssertEqual(pixel.blue, 220, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testQuadRectifyTransformEstimatesOutputSizeFromSourceQuad() {
        let filter = RenderQuadRectifyTransform(
            sourceQuad: .init(
                topLeft: .init(x: 0.1, y: 0.1),
                topRight: .init(x: 0.9, y: 0.15),
                bottomLeft: .init(x: 0.15, y: 0.9),
                bottomRight: .init(x: 0.85, y: 0.85)
            )
        )

        let outputSize = filter.resize(input: C7Size(width: 200, height: 100))
        XCTAssertGreaterThan(outputSize.width, 100)
        XCTAssertGreaterThan(outputSize.height, 60)
    }

    func testQuadRectifyTransformIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 40, green: 200, blue: 120, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: RenderQuadRectifyTransform(sourceQuad: .identity)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 40, accuracy: 2)
        XCTAssertEqual(pixel.green, 200, accuracy: 2)
        XCTAssertEqual(pixel.blue, 120, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testGuidedUprightRecognizesSupportedGuideCombinations() {
        let twoVertical = GuidedUpright(guides: [
            .init(start: .init(x: 0.2, y: 0.1), end: .init(x: 0.25, y: 0.9), axis: .vertical),
            .init(start: .init(x: 0.8, y: 0.1), end: .init(x: 0.75, y: 0.9), axis: .vertical)
        ])
        XCTAssertTrue(twoVertical.isSupportedCombination)

        let oneEach = GuidedUpright(guides: [
            .init(start: .init(x: 0.3, y: 0.1), end: .init(x: 0.35, y: 0.9), axis: .vertical),
            .init(start: .init(x: 0.1, y: 0.4), end: .init(x: 0.9, y: 0.45), axis: .horizontal)
        ])
        XCTAssertTrue(oneEach.isSupportedCombination)

        let invalid = GuidedUpright(guides: [
            .init(start: .init(x: 0.2, y: 0.1), end: .init(x: 0.25, y: 0.9), axis: .vertical),
            .init(start: .init(x: 0.4, y: 0.1), end: .init(x: 0.45, y: 0.9), axis: .vertical),
            .init(start: .init(x: 0.6, y: 0.1), end: .init(x: 0.65, y: 0.9), axis: .vertical)
        ])
        XCTAssertFalse(invalid.isSupportedCombination)
    }

    func testGuidedUprightReturnsQuadRectifyForTwoVerticalGuides() {
        let upright = GuidedUpright(guides: [
            .init(start: .init(x: 0.15, y: 0.1), end: .init(x: 0.25, y: 0.9), axis: .vertical),
            .init(start: .init(x: 0.85, y: 0.1), end: .init(x: 0.75, y: 0.9), axis: .vertical)
        ])

        let recommendation = upright.recommendTransform(inputSize: CGSize(width: 200, height: 100))
        switch recommendation {
        case .quadRectify(let filter):
            let size = filter.resize(input: C7Size(width: 200, height: 100))
            XCTAssertGreaterThan(size.width, 100)
        default:
            XCTFail("Expected quad rectify recommendation.")
        }
    }

    func testGuidedUprightReturnsPerspectiveForOneVerticalAndOneHorizontalGuide() {
        let upright = GuidedUpright(guides: [
            .init(start: .init(x: 0.3, y: 0.1), end: .init(x: 0.4, y: 0.9), axis: .vertical),
            .init(start: .init(x: 0.1, y: 0.4), end: .init(x: 0.9, y: 0.5), axis: .horizontal)
        ])

        let recommendation = upright.recommendTransform(inputSize: CGSize(width: 200, height: 100))
        switch recommendation {
        case .perspective(let transform):
            XCTAssertNotEqual(transform.rotate, 0, accuracy: 0.0001)
        default:
            XCTFail("Expected perspective recommendation.")
        }
    }

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create transform fixture texture.")
            throw HarbethError.textureLoader
        }

        let bytes: [UInt8] = [red, green, blue, alpha]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 4
        )
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}
