import Metal
import XCTest
@testable import Harbeth

final class HighPassSkinSmoothingTests: XCTestCase {

    func testPipelineContractExposesDetailGuideAndComposite() {
        let filter = C7HighPassSkinSmoothing(amount: 0.7, radius: 6)

        XCTAssertEqual(filter.pipelineExecutionStyle, .sequential)
        XCTAssertEqual(filter.pipelineFilters.count, 2)
        XCTAssertTrue(filter.pipelineFilters[1] is MPSGaussianBlur)
        XCTAssertEqual(filter.pipelineOtherInputCount, 1)
        XCTAssertEqual(filter.amount, 0.7, accuracy: 0.0001)
        XCTAssertEqual(filter.radius, 6, accuracy: 0.0001)
        XCTAssertEqual(filter.sharpnessFactor, 0, accuracy: 0.0001)
        XCTAssertEqual(C7HighPassSkinSmoothing.defaultToneCurveInputMidpoint, 120.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(C7HighPassSkinSmoothing.defaultToneCurveOutputMidpoint, 146.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(filter.factors.count, 6)
        XCTAssertEqual(filter.factors[3], 0, accuracy: 0.0001)
        XCTAssertEqual(filter.factors[4], C7HighPassSkinSmoothing.defaultToneCurveInputMidpoint, accuracy: 0.0001)
        XCTAssertEqual(filter.factors[5], C7HighPassSkinSmoothing.defaultToneCurveOutputMidpoint, accuracy: 0.0001)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 24))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
    }

    func testZeroRadiusUsesSafeIdentityGuideStage() {
        let filter = C7HighPassSkinSmoothing(radius: 0)

        XCTAssertTrue(filter.pipelineFilters[1] is C7GaussianBlur)
    }

    func testParametersClampToSafeRanges() {
        let filter = C7HighPassSkinSmoothing(
            amount: 2,
            radius: -4,
            detailThreshold: -1,
            detailTransition: 0,
            sharpnessFactor: 2,
            toneCurveInputMidpoint: 0,
            toneCurveOutputMidpoint: 2
        )

        XCTAssertEqual(filter.amount, 1)
        XCTAssertEqual(filter.radius, 0)
        XCTAssertEqual(filter.detailThreshold, 0)
        XCTAssertEqual(filter.detailTransition, 1.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(filter.sharpnessFactor, 1)
        XCTAssertEqual(filter.toneCurveInputMidpoint, 1.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(filter.toneCurveOutputMidpoint, 1)
    }

    func testAmountZeroPreservesTexture() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeSolidTexture(red: 52, green: 108, blue: 164, alpha: 192)

        let output = try HarbethIO(
            element: input,
            filters: [C7HighPassSkinSmoothing(amount: 0, radius: 8, sharpnessFactor: 1)]
        ).renderTexture(profile: .stablePreview)

        XCTAssertEqual(readPixel(output), [52, 108, 164, 192])
    }

    func testActiveSmoothingPreservesPremultipliedAlphaInvariant() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeSolidTexture(red: 64, green: 48, blue: 32, alpha: 128)

        let output = try HarbethIO(
            element: input,
            filter: C7HighPassSkinSmoothing(amount: 1, radius: 8)
        ).renderTexture(profile: .stablePreview)
        let pixel = readPixel(output)

        XCTAssertEqual(pixel[3], 128)
        XCTAssertLessThanOrEqual(pixel[0], pixel[3])
        XCTAssertLessThanOrEqual(pixel[1], pixel[3])
        XCTAssertLessThanOrEqual(pixel[2], pixel[3])
    }

    func testSharpnessFactorBoostsHighFrequencyDetail() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        let input = try makeTexture(width: 3, height: 3, pixels: [
            [64, 64, 64, 255], [64, 64, 64, 255], [64, 64, 64, 255],
            [64, 64, 64, 255], [192, 192, 192, 255], [64, 64, 64, 255],
            [64, 64, 64, 255], [64, 64, 64, 255], [64, 64, 64, 255]
        ])

        let softened = try HarbethIO(
            element: input,
            filter: C7HighPassSkinSmoothing(
                amount: 1,
                radius: 1,
                detailThreshold: 1,
                detailTransition: 1,
                sharpnessFactor: 0
            )
        ).renderTexture(profile: .stablePreview)
        let sharpened = try HarbethIO(
            element: input,
            filter: C7HighPassSkinSmoothing(
                amount: 1,
                radius: 1,
                detailThreshold: 1,
                detailTransition: 1,
                sharpnessFactor: 1
            )
        ).renderTexture(profile: .stablePreview)

        XCTAssertGreaterThan(readPixel(sharpened, x: 1, y: 1)[0], readPixel(softened, x: 1, y: 1)[0])
    }

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        try makeTexture(width: 4, height: 4, pixels: Array(repeating: [red, green, blue, alpha], count: 16))
    }

    private func makeTexture(width: Int, height: Int, pixels: [[UInt8]]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "high-pass-smoothing-input"
        )
        let bytes = pixels.flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func readPixel(_ texture: MTLTexture, x: Int = 0, y: Int = 0) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &pixel,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return pixel
    }
}
