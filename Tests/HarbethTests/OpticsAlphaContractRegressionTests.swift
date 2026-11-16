import Metal
// 由 Condy 创建于 2026/11/16。
import XCTest

@testable import Harbeth

final class OpticsAlphaContractRegressionTests: XCTestCase {
    func testOpticsRejectAutomaticTileAndPointwiseFusion() {
        let filters: [any C7FilterProtocol] = [
            C7ChromaticAberrationCorrection(redCyanShift: 0.2), C7LensDistortionCorrection(distortion: 0.2),
        ]
        for filter in filters {
            XCTAssertEqual(filter.kernelPixelContract.inputAlphaExpectation, .premultiplied)
            XCTAssertEqual(filter.kernelPixelContract.coordinateDependency, .fullImage)
            XCTAssertEqual(filter.kernelPixelContract.globalDependency, .imageDimensions)
            XCTAssertEqual(filter.samplingFootprint, .global)
            XCTAssertFalse(filter.kernelPixelContract.canAutoTile)
            XCTAssertFalse(filter.kernelPixelContract.isPointwiseFusionEligible)
        }
    }

    func testPremultipliedChannelsAndTransparentCompositeAcrossSamplingModes() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
            for mode in [SpatialSamplingMode.nearest, .linear, .adaptive] {
                for edge in [SpatialEdgeMode.transparent, .clamp, .repeat, .mirrorRepeat] {
                    let baseline: MTLTexture = try HarbethIO(
                        element: input.texture,
                        filter: C7ChromaticAberrationCorrection(
                            redCyanShift: 0, blueYellowShift: 0, samplingMode: mode, edgeMode: edge)
                    ).output()
                    let base = try NeighborhoodTestImage.read(baseline)
                    let filter = C7ChromaticAberrationCorrection(
                        redCyanShift: 0.2, blueYellowShift: -0.1, samplingMode: mode, edgeMode: edge)
                    let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                    let actual = try NeighborhoodTestImage.read(output)
                    for i in stride(from: 0, to: actual.count, by: 4) {
                        XCTAssertTrue(actual[i..<i + 4].allSatisfy(\.isFinite))
                        if actual[i + 3] == 0 { XCTAssertEqual(Array(actual[i..<i + 3]), [0, 0, 0]) }
                        if mode != .adaptive {
                            for c in 0..<3 { XCTAssertLessThanOrEqual(actual[i + c], actual[i + 3] + 0.005) }
                        }
                        XCTAssertEqual(actual[i + 3], base[i + 3])
                        // 与黑底做预乘 over 时，实际透明像素不能贡献任何色光。
                        if actual[i + 3] == 0 { for c in 0..<3 { XCTAssertEqual(actual[i + c], 0) } }
                    }
                }
            }
        }
    }

    func testOpaqueLinearBordersKeepOriginalChannelSampling() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba16Float)
        var values = input.values
        for i in stride(from: 3, to: values.count, by: 4) { values[i] = 1 }
        let half = values.map { Float16($0) }
        half.withUnsafeBytes {
            input.texture.replace(
                region: MTLRegionMake2D(0, 0, 17, 13), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 17 * 8)
        }
        let filter = C7ChromaticAberrationCorrection(
            redCyanShift: 0.2, blueYellowShift: -0.1, samplingMode: .linear, edgeMode: .transparent)
        let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
        let actual = try NeighborhoodTestImage.read(output)
        func sample(_ u: Double, _ v: Double, _ c: Int) -> Double {
            let px = u * 17 - 0.5
            let py = v * 13 - 0.5
            let x = Int(floor(px))
            let y = Int(floor(py))
            let fx = px - Double(x)
            let fy = py - Double(y)
            var result = 0.0
            for dy in 0...1 {
                for dx in 0...1 where (0..<17).contains(x + dx) && (0..<13).contains(y + dy) {
                    result +=
                        Double(values[((y + dy) * 17 + x + dx) * 4 + c]) * (dx == 0 ? 1 - fx : fx)
                        * (dy == 0 ? 1 - fy : fy)
                }
            }
            return result
        }
        for y in 0..<13 {
            for x in 0..<17 {
                let u = (Double(x) + 0.5) / 17
                let v = (Double(y) + 0.5) / 13
                let rx = u - 0.5
                let ry = (v - 0.5) * 13 / 17
                let r2 = rx * rx + ry * ry
                let length = sqrt(r2)
                let dx = length > 0.001 ? rx / length * r2 : 0
                let dy = length > 0.001 ? ry / length * r2 * 17 / 13 : 0
                XCTAssertEqual(
                    actual[(y * 17 + x) * 4],
                    Float(sample(u + dx * Double(Float(0.2)), v + dy * Double(Float(0.2)), 0)), accuracy: 0.003)
                XCTAssertEqual(
                    actual[(y * 17 + x) * 4 + 2],
                    Float(sample(u + dx * Double(Float(-0.1)), v + dy * Double(Float(-0.1)), 2)), accuracy: 0.003)
                XCTAssertEqual(actual[(y * 17 + x) * 4 + 3], 1)
            }
        }
    }

    func testZeroShiftIsIdentityIncludingTransparentPixels() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
            let filter = C7ChromaticAberrationCorrection(
                redCyanShift: 0, blueYellowShift: 0, samplingMode: .nearest, edgeMode: .clamp)
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            input.assertPixels(try NeighborhoodTestImage.read(output), input.values)
        }
    }
}
