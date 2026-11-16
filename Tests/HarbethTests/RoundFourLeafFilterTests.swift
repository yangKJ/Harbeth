import Metal
// 由 Condy 创建于 2026/11/16。
import XCTest

@testable import Harbeth

final class RoundFourLeafFilterTests: XCTestCase {
    func testNonFiniteParametersNormalizeBeforeIntegerPlanning() {
        for value: Float in [.nan, .infinity, -.infinity, -100, 0, 1, 2, 4, 100] {
            let morphology = C7Morphology(operation: .erosion, kernelSize: value)
            XCTAssertTrue((1...9).contains(morphology.normalizedKernelSize))
            XCTAssertFalse(morphology.normalizedKernelSize.isMultiple(of: 2))
            XCTAssertTrue(morphology.factors.allSatisfy(\.isFinite))
            let surface = C7SurfaceBlur(radius: value)
            XCTAssertTrue(surface.factors.allSatisfy(\.isFinite))
            XCTAssertTrue(surface.kernelPixelContract.samplingFootprint.isValid)
        }
    }

    func testZeroAndEmptyNeighborhoodPathsPreserveFloat32Bits() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba32Float)
        var mutable = C7SharpenEnhanced(kernelSize: 3)
        mutable.kernelSize = Int.max
        XCTAssertEqual(mutable.factors[2], 5)
        mutable.kernelSize = Int.min
        XCTAssertEqual(mutable.factors[2], 1)
        let filters: [any C7FilterProtocol] = [
            C7SharpenEnhanced(kernelSize: 1), C7SharpenEnhanced(intensity: 0, kernelSize: 5), mutable,
            C7EdgeAwareSharpen(amount: 0), C7EdgeAwareSharpen(amount: 1, edgeThreshold: 1),
            C7SharpenDetail(sharpen: 0, clarity: 0, detail: 0), C7PolarPixellate(scale: 0),
            C7SurfaceBlur(radius: .nan), C7SurfaceBlur(radius: 0),
        ]
        let expected = try XCTUnwrap(input.texture.c7.rawBytes(maximumBytes: 17 * 13 * 16))
        for filter in filters {
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: expected.count), expected, String(describing: filter))
        }
    }

    func testEdgeAwareHDRSpikeMatchesIndependentLaplacian() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage(width: 3, height: 3, format: format, constant: 0)
            var values = input.values
            for c in 0..<3 { values[16 + c] = 20000 }
            try upload(values, to: input.texture)
            for amount: Float in [0, 0.5, 1] {
                let output: MTLTexture = try HarbethIO(
                    element: input.texture, filter: C7EdgeAwareSharpen(amount: amount, edgeThreshold: 0.3)
                ).output()
                let actual = try NeighborhoodTestImage.read(output)
                var expected = values
                for y in 0..<3 {
                    for x in 0..<3 {
                        let i = (y * 3 + x) * 4
                        var lap = [Double](repeating: 0, count: 3)
                        for (dx, dy) in [(0, -1), (-1, 0), (1, 0), (0, 1)] {
                            let n = (min(max(y + dy, 0), 2) * 3 + min(max(x + dx, 0), 2)) * 4
                            for c in 0..<3 { lap[c] += Double(values[n + c]) - Double(values[i + c]) }
                        }
                        let edge = min((abs(lap[0]) * 0.299 + abs(lap[1]) * 0.587 + abs(lap[2]) * 0.114) / 4, 1)
                        let strength = edge > 0.3 ? Double(amount) * (edge - 0.3) / 0.7 : 0
                        for c in 0..<3 { expected[i + c] = Float(Double(values[i + c]) - lap[c] * strength * 0.25) }
                    }
                }
                input.assertPixels(actual, expected, tolerance: 4)
                XCTAssertEqual(actual[16], 20000 * (1 + amount), accuracy: 4)
            }
        }
    }

    func testDetailSharpeningKeepsUniformHDRAndAlpha() throws {
        for value: Float in [20000, 65504] {
            let input = try NeighborhoodTestImage(width: 9, height: 7, format: .rgba16Float, constant: value)
            for filter in [
                C7SharpenDetail(sharpen: 0, clarity: 1, detail: 0), C7SharpenDetail(sharpen: 1, clarity: 1, detail: 1),
            ] {
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                input.assertPixels(try NeighborhoodTestImage.read(output), input.values, tolerance: value * 0.001)
            }
        }
    }

    func testRedMonochromeUsesSignedClampedDiagonalAndDirectionalSamples() throws {
        let input = try NeighborhoodTestImage(width: 5, height: 7, format: .rgba32Float, constant: 0)
        var pixels = input.values
        pixels[(1 * 5 + 4) * 4] = 1
        try upload(pixels, to: input.texture)
        for (horizontal, vertical) in [(true, true), (true, false), (false, true), (false, false)] {
            var filter = C7RedMonochromeBlur(pixelRadius: 2)
            filter.horizontal = horizontal
            filter.vertical = vertical
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            let actual = try NeighborhoodTestImage.read(output)
            for y in 0..<7 {
                for x in 0..<5 {
                    var maximum: Float = 0
                    if horizontal || vertical {
                        for offset in -2...2 {
                            let sx = min(max(x + (horizontal ? offset : 0), 0), 4)
                            let sy = min(max(y + (vertical ? offset : 0), 0), 6)
                            maximum = max(maximum, pixels[(sy * 5 + sx) * 4])
                        }
                    }
                    for c in 0..<3 { XCTAssertEqual(actual[(y * 5 + x) * 4 + c], maximum) }
                    XCTAssertEqual(actual[(y * 5 + x) * 4 + 3], 1)
                }
            }
        }
    }

    func testEdgeGlowHasZeroDCResponseAtZeroThresholdForDecimalConstants() throws {
        for format in NeighborhoodTestImage.formats {
            for value: Float in [0.1, 0.3, 0.5] {
                let input = try NeighborhoodTestImage(width: 17, height: 13, format: format, constant: value)
                let output: MTLTexture = try HarbethIO(
                    element: input.texture, filter: C7EdgeGlow(time: 0.2, spacing: 0)
                ).output()
                input.assertPixels(try NeighborhoodTestImage.read(output), input.values)
            }
        }
    }

    func testNondegenerateEnhancedSharpenMatchesIndependentMean() throws {
        let input = try NeighborhoodTestImage(width: 9, height: 7, format: .rgba32Float)
        for size in [3, 5] {
            let filter = C7SharpenEnhanced(intensity: 1.3, threshold: 0.037, kernelSize: size)
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            var expected = input.values
            let r = size / 2
            for y in 0..<7 {
                for x in 0..<9 {
                    var mean = [Double](repeating: 0, count: 4)
                    var count = 0.0
                    for dy in -r...r {
                        for dx in -r...r where dx != 0 || dy != 0 {
                            let i = (min(max(y + dy, 0), 6) * 9 + min(max(x + dx, 0), 8)) * 4
                            for c in 0..<4 { mean[c] += Double(input.values[i + c]) }
                            count += 1
                        }
                    }
                    let i = (y * 9 + x) * 4
                    let edge = (0..<4).map { Double(input.values[i + $0]) - mean[$0] / count }
                    if sqrt(edge[0] * edge[0] + edge[1] * edge[1] + edge[2] * edge[2]) >= Double(Float(0.037)) {
                        for c in 0..<4 {
                            expected[i + c] = Float(Double(input.values[i + c]) + edge[c] * Double(Float(1.3)))
                        }
                    }
                }
            }
            input.assertPixels(try NeighborhoodTestImage.read(output), expected, tolerance: 0.00003)
        }
    }

    func testDetailSharpeningMatchesIndependentMixedFormulaAndSpacing() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba16Float)
        for spacing: Float in [1, 0.5] {
            let filter = C7SharpenDetail(sharpen: 0.4, clarity: 0.5, detail: 0.6, sampleSpacing: spacing)
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            func pixel(_ x: Double, _ y: Double, _ channel: Int) -> Double {
                let px = min(max(x, 0), 16)
                let py = min(max(y, 0), 12)
                let ix = Int(floor(px))
                let iy = Int(floor(py))
                let fx = px - Double(ix)
                let fy = py - Double(iy)
                var result = 0.0
                for dy in 0...1 {
                    for dx in 0...1 {
                        let index = (min(iy + dy, 12) * 17 + min(ix + dx, 16)) * 4 + channel
                        result += Double(input.values[index]) * (dx == 0 ? 1 - fx : fx) * (dy == 0 ? 1 - fy : fy)
                    }
                }
                return result
            }
            var expected = input.values
            for y in 0..<13 {
                for x in 0..<17 {
                    let center = (0..<3).map { Double(input.values[(y * 17 + x) * 4 + $0]) }
                    var mean = [Double](repeating: 0, count: 3)
                    var lap = [Double](repeating: 0, count: 3)
                    var detail = center.map { $0 * 2 }
                    for dy in -1...1 {
                        for dx in -1...1 {
                            for c in 0..<3 {
                                let p = pixel(
                                    Double(x) + Double(dx) * Double(spacing), Double(y) + Double(dy) * Double(spacing),
                                    c)
                                mean[c] += p / 9
                                lap[c] += p * (dx == 0 && dy == 0 ? 9 : -1)
                                if abs(dx) + abs(dy) == 1 { detail[c] -= p * 0.25 }
                            }
                        }
                    }
                    var color = (0..<3).map { center[$0] + (lap[$0] - center[$0]) * Double(Float(0.4)) }
                    let lum =
                        color[0] * Double(Float(0.2125)) + color[1] * Double(Float(0.7154)) + color[2]
                        * Double(Float(0.0721))
                    let t = min(
                        max((abs(lum - 0.5) * 2 - Double(Float(0.35))) / (Double(Float(0.9)) - Double(Float(0.35))), 0),
                        1)
                    let mask = 1 - t * t * (3 - 2 * t)
                    for c in 0..<3 {
                        color[c] += (color[c] - mean[c]) * 0.5 * mask * 0.75
                        color[c] += (detail[c] - color[c]) * Double(Float(0.6)) * 0.5
                        expected[(y * 17 + x) * 4 + c] = Float(color[c])
                    }
                }
            }
            input.assertPixels(try NeighborhoodTestImage.read(output), expected, tolerance: 0.002)
        }
    }

    func testPolarNonzeroKeepsItsOriginalRadialQuantization() throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba32Float)
        let scale: Float = 0.173
        let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7PolarPixellate(scale: scale)).output()
        let actual = try NeighborhoodTestImage.read(output)
        let s = Double(scale)
        for (x, y) in [(2, 2), (5, 7), (15, 11)] {
            let u = Double(x) / 17 * 2 - 1
            let v = Double(y) / 13 * 2 - 1
            let radius = floor(sqrt(u * u + v * v) / s) * s + 0.03
            let angle = floor(atan2(v, u) / s) * s
            let sx = Int(min(max((radius * cos(angle) / 2 + 0.5) * 17, 0), 16))
            let sy = Int(min(max((radius * sin(angle) / 2 + 0.5) * 13, 0), 12))
            for c in 0..<4 {
                XCTAssertEqual(actual[(y * 17 + x) * 4 + c], input.values[(sy * 17 + sx) * 4 + c], accuracy: 0.00002)
            }
        }
    }

    private func upload(_ values: [Float], to texture: MTLTexture) throws {
        if texture.pixelFormat == .rgba16Float {
            let half = values.map { Float16($0) }
            half.withUnsafeBytes {
                texture.replace(
                    region: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0,
                    withBytes: $0.baseAddress!, bytesPerRow: texture.width * 8)
            }
        } else {
            values.withUnsafeBytes {
                texture.replace(
                    region: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0,
                    withBytes: $0.baseAddress!, bytesPerRow: texture.width * 16)
            }
        }
    }
}
