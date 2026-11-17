// 由 Condy 创建于 2026/11/17。
import XCTest
import Metal
@testable import Harbeth

final class OpticsOverlayRegressionTests: XCTestCase {
    func testVignetteGainClampsStraightColorsThenRestoresCoverage() throws {
        XCTAssertFalse(C7LensVignetteCorrection().kernelPixelContract.canAutoTile)
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for alpha: Float in [0, 0.25, 1] {
                let source = try R7Pixels.make(width: 5, height: 5, pixels: Array(repeating: [alpha, alpha * 0.5, alpha * 0.25, alpha], count: 25).flatMap { $0 }, format: format)
                for amount: Float in [-1, 1, 2] {
                    let output: MTLTexture = try HarbethIO(element: source, filter: C7LensVignetteCorrection(amount: amount, start: 0, end: 0.01)).output()
                    let actual = try NeighborhoodTestImage.read(output)
                    for y in 0..<5 { for x in 0..<5 { for c in 0..<4 {
                        // 中心没有补偿，其他像素超过羽化范围。
                        let gain = x == 2 && y == 2 ? 1 : pow(2.0, Double(amount))
                        let expected = c == 3 ? alpha : min([Float](arrayLiteral: 1, 0.5, 0.25)[c] * Float(gain), 1) * alpha
                        XCTAssertEqual(actual[(y * 5 + x) * 4 + c], expected, accuracy: 0.001)
                    } } }
                }
            }
        }
    }

    func testDefringeDoesNotInterpretCoverageAsColorEdge() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            var pixels: [Float] = []
            for i in 0..<25 { let a: Float = i == 0 ? 0.25 : i == 24 ? 0 : 1; pixels += [a, 0.2 * a, a, a] }
            let source = try R7Pixels.make(width: 5, height: 5, pixels: pixels, format: format)
            let output: MTLTexture = try HarbethIO(element: source, filter: C7DefringeCorrection(purpleAmount: 1)).output()
            let actual = try NeighborhoodTestImage.read(output), expected = try NeighborhoodTestImage.read(source)
            for i in actual.indices { XCTAssertEqual(actual[i], expected[i], accuracy: 0.001) }
        }
    }

    func testDefringeHueWrapThresholdEndpointsAndPremultiplication() throws {
        // 红色接近 360 度；相邻黑色提供真正的颜色边缘。
        for alpha: Float in [0.25, 1] { for saturation: Float in [0, 0.15, 1] {
            for rgb: [Float] in [[1, 0, 0], [1, 0.1, 0.15], [0.1, 1, 0.1]] {
                let source = try R7Pixels.make(width: 3, height: 1, pixels: [0, 0, 0, alpha] + rgb.map { $0 * alpha } + [alpha] + [0, 0, 0, alpha], format: .rgba32Float)
                let filter = C7DefringeCorrection(purpleAmount: 1, purpleHueStart: 350, purpleHueEnd: 20,
                    greenAmount: 1, greenHueStart: 90, greenHueEnd: 170, edgeThreshold: 0.01, saturationThreshold: saturation)
                let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                let actual = try NeighborhoodTestImage.read(output)
                let expected = defringe(rgb.map(Double.init), alpha: Double(alpha), saturationThreshold: Double(saturation))
                for c in 0..<4 { XCTAssertEqual(actual[4 + c], Float(expected[c]), accuracy: 0.00002) }
            }
        } }
        let invalid = C7DefringeCorrection(purpleAmount: .nan, purpleHueStart: .infinity, greenAmount: .infinity,
            greenHueEnd: .nan, edgeThreshold: .nan, saturationThreshold: .infinity)
        XCTAssertTrue(invalid.factors.allSatisfy(\.isFinite))
        XCTAssertEqual(C7DefringeCorrection(purpleHueStart: -10, purpleHueEnd: 380).factors[1...2], [350, 20])
    }

    private func defringe(_ rgb: [Double], alpha: Double, saturationThreshold: Double) -> [Double] {
        func smooth(_ lo: Double, _ hi: Double, _ x: Double) -> Double { let t = min(max((x - lo) / (hi - lo), 0), 1); return t * t * (3 - 2 * t) }
        let maximum = rgb.max()!, minimum = rgb.min()!, delta = maximum - minimum, light = (maximum + minimum) / 2
        let sat = delta > 0.000001 ? delta / max(0.000001, 1 - abs(2 * light - 1)) : 0
        var hue = delta <= 0.000001 ? 0 : maximum == rgb[0] ? 60 * ((rgb[1] - rgb[2]) / delta).truncatingRemainder(dividingBy: 6) : maximum == rgb[1] ? 60 * ((rgb[2] - rgb[0]) / delta + 2) : 60 * ((rgb[0] - rgb[1]) / delta + 4)
        if hue < 0 { hue += 360 }
        func coverage(_ start: Double, _ end: Double) -> Double {
            if start <= end ? hue >= start && hue <= end : hue >= start || hue <= end { return 1 }
            func distance(_ a: Double) -> Double { let d = abs(hue - a); return min(d, 360 - d) }
            return 1 - smooth(0, 10, min(distance(start), distance(end)))
        }
        let luma = zip(rgb, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
        let edge = smooth(0.01, 0.03, luma), sf = saturationThreshold == 1 ? (sat >= 1 ? 1.0 : 0.0) : smooth(saturationThreshold, 1, sat)
        let purple = coverage(350, 20) * edge * sf, green = coverage(90, 170) * edge * sf
        var corrected = rgb
        for c in [0, 2] { corrected[c] += (max(rgb[1], luma) - corrected[c]) * purple }
        corrected[1] += (max((rgb[0] + rgb[2]) / 2, luma) - corrected[1]) * green
        return corrected.map { min(max($0, 0), 1) * alpha } + [alpha]
    }

    func testStickerMatchesIndependentSearchAndBlurIncludingPrunedContent() throws {
        for kind in 0..<3 { for blur: Float in [0, 0.4] {
            let w = 33, h = 17
            var values: [Float] = []
            for y in 0..<h { for x in 0..<w {
                let value: Float = kind == 0 ? Float((x + y) % 2) : kind == 1 ? 0.5 : Float((x * 7 + y * 13) % 19) / 18
                values += [value, value, value, 1]
            } }
            let source = try R7Pixels.make(width: w, height: h, pixels: values, format: .rgba32Float)
            let filter = C7StickerOutline(outlineColor: C7Color(red: 1, green: 0, blue: 0, alpha: 0.25), outlineThickness: 0.1, outlineBlur: blur)
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            let actual = try NeighborhoodTestImage.read(output), expected = sticker(values, width: w, height: h, blur: Double(blur))
            for i in actual.indices { if abs(actual[i] - expected[i]) > 0.00002 { XCTFail("轮廓分量 \(i)：\(actual[i]) vs \(expected[i])"); break } }
        } }
    }

    func testStickerGroupPruningAndUnspecializedFallbackProduceIdenticalPixels() throws {
        let filter = C7StickerOutline(outlineThickness: 0.1, outlineBlur: 0.4)
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage(width: 33, height: 17, format: format)
            let expected: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            for specialized in [-1, 0, 1] {
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: R7StickerFallback(base: filter, specialization: specialized)).output()
                XCTAssertEqual(output.c7.rawBytes(maximumBytes: 33 * 17 * 16), expected.c7.rawBytes(maximumBytes: 33 * 17 * 16))
            }
        }
    }

    private func sticker(_ values: [Float], width: Int, height: Int, blur: Double) -> [Float] {
        let radius = max(1, Int(Float(width) * 0.1)), outline = [0.25, 0.0, 0.0, 0.25]
        var result = values
        for y in 0..<height { for x in 0..<width {
            let base = (y * width + x) * 4, original = (0..<4).map { Double(values[base + $0]) }
            var strength = 0.0, edge = false
            for dx in -radius...radius { for dy in -radius...radius where dx != 0 || dy != 0 {
                if !(0..<width).contains(x + dx) || !(0..<height).contains(y + dy) { continue }
                let i = ((y + dy) * width + x + dx) * 4
                let difference = sqrt((0..<3).reduce(0.0) { $0 + pow(Double(values[i + $1]) - original[$1], 2) })
                if difference > 0.3 { edge = true; strength = max(strength, (1 - sqrt(Double(dx * dx + dy * dy)) / Double(radius)) * difference) }
            } }
            guard edge else { continue }
            let t = min(strength, 1) * 0.8, edgeColor = (0..<4).map { original[$0] * (1 - t) + outline[$0] * t }
            var final = edgeColor
            if blur > 0 {
                let br = max(1, Int(blur * Double(radius) * 2)), center = edgeColor
                var sum = center, weight = 1.0
                for dx in -br...br { for dy in -br...br where dx != 0 || dy != 0 {
                    if !(0..<width).contains(x + dx) || !(0..<height).contains(y + dy) { continue }
                    let w = 1 / (1 + sqrt(Double(dx * dx + dy * dy)) * 0.5), i = ((y + dy) * width + x + dx) * 4
                    for c in 0..<4 { sum[c] += Double(values[i + c]) * w }; weight += w
                } }
                final = (0..<4).map { center[$0] * (1 - blur) + sum[$0] / weight * blur }
            }
            for c in 0..<4 { result[base + c] = Float(final[c]) }
        } }
        return result
    }

    func testVoronoiOpacityAndInvalidParameterFallbacks() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let source = try R7Pixels.make(width: 17, height: 13, pixels: nil, format: format)
            for alpha: Float in [0, 0.05, 1, -2, 2, .nan, .infinity] {
                let filter = C7VoronoiOverlay(time: .nan, alpha: alpha)
                let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                let actual = try NeighborhoodTestImage.read(output), a = filter.factors[1]
                for i in stride(from: 0, to: actual.count, by: 4) {
                    XCTAssertEqual(actual[i + 3], a, accuracy: 0.001)
                    for c in 0..<3 { XCTAssertTrue(actual[i + c].isFinite); XCTAssertGreaterThanOrEqual(actual[i + c], 0); XCTAssertLessThanOrEqual(actual[i + c], actual[i + 3] + 0.001) }
                }
            }
        }
        var invalid = C7VoronoiOverlay(); invalid.iResolution = C7Point2D(x: 0, y: .infinity)
        XCTAssertEqual(invalid.factors[2...3], [0.5, 1])
    }

    func testVoronoiFieldMatchesDirectAcrossAllMetricPhasesAndResolution() throws {
        for n in [512, 1024] { for phase: Float in [0.5, 4.5, 5.5, 9.5, 10.5, 14.5] { for resolution: Float in [0.25, 0.5, 1] {
            try autoreleasepool {
                var filter = C7VoronoiOverlay(time: phase, alpha: 1); filter.iResolution.x = resolution
                let input = try NeighborhoodTestImage(width: n, height: n, format: .rgba16Float)
                let direct = try render(filter, source: input.texture, limit: 0), field = try render(filter, source: input.texture, limit: 4 * 1024 * 1024)
                let a = try NeighborhoodTestImage.read(direct), b = try NeighborhoodTestImage.read(field)
                var maximum: Float = 0, total = 0.0
                for i in a.indices { let difference = abs(a[i] - b[i]); maximum = max(maximum, difference); total += Double(difference) }
                XCTAssertLessThanOrEqual(maximum, 0.001, "尺寸 \(n)，相位 \(phase)，分辨率 \(resolution)")
                XCTAssertLessThanOrEqual(total / Double(a.count), 0.000001)
            }
        } } }
    }

    func testVoronoiRectangularHDRAndSignedInputsKeepFiniteHalfPrecision() throws {
        for value: Float in [-2, 20000, 65504] { for alpha: Float in [0.05, 1] {
            let input = try NeighborhoodTestImage(width: 512, height: 513, format: .rgba16Float, constant: value)
            let filter = C7VoronoiOverlay(time: 9.5, alpha: alpha)
            let direct = try render(filter, source: input.texture, limit: 0), field = try render(filter, source: input.texture, limit: 4 * 1024 * 1024)
            let a = try NeighborhoodTestImage.read(direct), b = try NeighborhoodTestImage.read(field)
            for i in a.indices {
                XCTAssertTrue(b[i].isFinite)
                let limit = max(0.001, Float(Float16(a[i]).ulp))
                if abs(a[i] - b[i]) > limit { XCTFail("HDR 格点误差超过半精度末位：\(a[i]) vs \(b[i])"); break }
            }
        } }
    }

    func testVoronoiResourceLimitsAndFallbackRoutes() throws {
        let filter = C7VoronoiOverlay()
        XCTAssertNil(filter.fieldSide(width: 256, height: 256, maximumTemporaryBytes: 4 * 1024 * 1024))
        XCTAssertNil(filter.fieldSide(width: 1024, height: 1024, maximumTemporaryBytes: 0))
        var dense = filter; dense.iResolution.x = 0.000001
        XCTAssertNil(dense.fieldSide(width: 1024, height: 1024, maximumTemporaryBytes: 4 * 1024 * 1024))
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage(width: 512, height: 512, format: format)
            let a = try render(filter, source: input.texture, limit: 0), b = try render(filter, source: input.texture, limit: 1)
            XCTAssertEqual(a.c7.rawBytes(maximumBytes: 512 * 512 * 16), b.c7.rawBytes(maximumBytes: 512 * 512 * 16))
        }
    }

    func testVoronoiConcurrentBudgetExhaustionKeepsDirectResult() throws {
        let runtime = HarbethContext.shared, budget = runtime.voronoiCellBudget, limit = 1024 * 1024
        XCTAssertTrue(budget.reserve(limit, limit: limit))
        defer { budget.release(limit) }
        let input = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba16Float)
        let direct = try render(C7VoronoiOverlay(), source: input.texture, limit: 0)
        let exhausted = try render(C7VoronoiOverlay(), source: input.texture, limit: limit)
        XCTAssertEqual(direct.c7.rawBytes(maximumBytes: 512 * 512 * 8), exhausted.c7.rawBytes(maximumBytes: 512 * 512 * 8))
        XCTAssertEqual(budget.usedBytes, limit)
    }

    func testVoronoiLeasesSurvivePurgeAndIndependentInFlightCommands() throws {
        let runtime = HarbethContext.shared, budget = runtime.voronoiCellBudget, initial = budget.usedBytes
        let source = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba16Float)
        let queue = try XCTUnwrap(runtime.device.makeCommandQueue())
        // 未提交命令销毁后也必须归还额度。
        try autoreleasepool {
            let command = try XCTUnwrap(queue.makeCommandBuffer()), output = try R7Pixels.make(width: 512, height: 512, pixels: nil)
            _ = try C7VoronoiOverlay().encode(context: MetalCommandEncodingContext(commandBuffer: command, textures: [output, source.texture]), maximumTemporaryBytes: 1024 * 1024)
            XCTAssertEqual(budget.usedBytes, initial + 6400)
            budget.purge(); XCTAssertEqual(budget.usedBytes, initial + 6400)
        }
        XCTAssertEqual(budget.usedBytes, initial)
        var commands: [MTLCommandBuffer] = [], outputs: [MTLTexture] = []
        for time: Float in [0.5, 5.5, 10.5] {
            let command = try XCTUnwrap(queue.makeCommandBuffer()), output = try R7Pixels.make(width: 512, height: 512, pixels: nil)
            _ = try C7VoronoiOverlay(time: time).encode(context: MetalCommandEncodingContext(commandBuffer: command, textures: [output, source.texture]), maximumTemporaryBytes: 1024 * 1024)
            commands.append(command); outputs.append(output)
        }
        XCTAssertEqual(budget.usedBytes, initial + 3 * 6400)
        let done = expectation(description: "格点租约归还")
        done.expectedFulfillmentCount = commands.count
        for command in commands { command.addCompletedHandler { _ in done.fulfill() }; command.commit() }
        for command in commands { command.waitUntilCompleted(); XCTAssertEqual(command.status, .completed) }
        wait(for: [done], timeout: 5)
        for (i, time): (Int, Float) in [0.5, 5.5, 10.5].enumerated() {
            let expected = try render(C7VoronoiOverlay(time: time), source: source.texture, limit: 0)
            let a = try NeighborhoodTestImage.read(outputs[i]), b = try NeighborhoodTestImage.read(expected)
            XCTAssertLessThanOrEqual(zip(a, b).map { abs($0 - $1) }.max()!, 0.001)
        }
        XCTAssertEqual(budget.usedBytes, initial)
    }

    private func render(_ filter: C7VoronoiOverlay, source: MTLTexture, limit: Int) throws -> MTLTexture {
        let output = try R7Pixels.make(width: source.width, height: source.height, pixels: nil, format: source.pixelFormat)
        let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
        _ = try filter.encode(context: MetalCommandEncodingContext(commandBuffer: command, textures: [output, source]), maximumTemporaryBytes: limit)
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(command.status, .completed)
        return output
    }
}

private struct R7StickerFallback: C7FilterProtocol {
    let base: C7StickerOutline
    let specialization: Int
    var modifier: ModifierEnum { base.modifier }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] {
        specialization < 0 ? [] : [.init(name: "stickerUsesSIMDGroup", index: 0, value: .bool(specialization == 1))]
    }
}
