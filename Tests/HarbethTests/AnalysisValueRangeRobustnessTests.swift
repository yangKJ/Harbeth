import Metal
// 由 Condy 创建于 2026/11/16。
import XCTest

@testable import Harbeth

final class AnalysisValueRangeRobustnessTests: XCTestCase {
    func testEqualRangesUseRepresentableWindowAndKeepUnitExpansion() throws {
        for value: Float in [0, 5, -5] {
            let range = TextureAnalysisValueRange(minimum: value, maximum: value)
            XCTAssertEqual(range.minimum, value)
            XCTAssertEqual(range.maximum, value + 1)
        }
        for value: Float in [1e8, .greatestFiniteMagnitude, -.greatestFiniteMagnitude] {
            let range = TextureAnalysisValueRange(minimum: value, maximum: value)
            XCTAssertTrue(range.minimum.isFinite && range.maximum.isFinite)
            XCTAssertLessThan(range.minimum, range.maximum)
            XCTAssertEqual(range.normalizedValue(range.minimum), 0)
            XCTAssertEqual(range.normalizedValue(range.maximum), 1)
        }
        let raw = Data(#"{"minimum":5,"maximum":5}"#.utf8)
        let decoded = try JSONDecoder().decode(TextureAnalysisValueRange.self, from: raw)
        XCTAssertEqual(decoded.maximum, 6)
    }

    func testNormalizationMatchesDoubleAcrossWideAndNarrowWindows() {
        let max = Float.greatestFiniteMagnitude
        for (lo, hi): (Float, Float) in [
            (0, 1), (-max, max), (-max, 0), (0, max), (max.nextDown, max), (1e8, Float(1e8).nextUp),
        ] {
            let range = TextureAnalysisValueRange(minimum: hi, maximum: lo)
            for value in [lo, lo.nextUp, 0, hi.nextDown, hi] {
                let expected = Float(
                    Swift.min(
                        Swift.max(
                            (Double(value) - Double(range.minimum)) / (Double(range.maximum) - Double(range.minimum)), 0
                        ), 1))
                XCTAssertEqual(range.normalizedValue(value), expected, accuracy: 0.000001)
            }
            XCTAssertTrue(range.normalizedValue(.nan).isNaN)
            XCTAssertEqual(range.normalizedValue(-.infinity), 0)
            XCTAssertEqual(range.normalizedValue(.infinity), 1)
        }
    }

    func testCPUAndGPUHistogramAgreeForOverflowingAndEqualWindows() throws {
        let max = Float.greatestFiniteMagnitude
        for range in [
            TextureAnalysisValueRange(minimum: -max, maximum: max), .init(minimum: 1e8, maximum: 1e8),
            .init(minimum: max, maximum: max),
        ] {
            let source = try NeighborhoodTestImage(
                width: 9, height: 7, format: .rgba32Float, constant: range.minimum / 2 + range.maximum / 2)
            let scope = TextureAnalysisScope(valueRange: range)
            for bins in [3, 257, 4096] {
                let cpu = try XCTUnwrap(
                    source.texture.c7.makeHistogram(
                        channel: .red, bins: bins, scope: scope, preferredMethod: .cpuReadback))
                let gpu = try XCTUnwrap(
                    GPUTextureAnalysis.histogram(source.texture, channel: .red, bins: bins, scope: scope))
                XCTAssertEqual(cpu.bins, gpu.bins)
                XCTAssertEqual(cpu.totalSampleCount, 63)
            }
        }
    }

    func testGPUScopesUseTheSameOverflowSafeNormalization() throws {
        let input = try NeighborhoodTestImage(width: 9, height: 7, format: .rgba32Float, constant: 0)
        let midpoint = try NeighborhoodTestImage(width: 9, height: 7, format: .rgba32Float, constant: 0.5)
        for kind in [TextureImageScopeKind.luminanceWaveform, .rgbWaveform, .vectorscope] {
            let extreme = TextureImageScopeConfiguration(
                kind: kind, width: 17, height: 13, intensity: 1, pixelFormat: .rgba8Unorm,
                valueRange: .init(minimum: -.greatestFiniteMagnitude, maximum: .greatestFiniteMagnitude),
                normalizesDensity: false)
            let normal = TextureImageScopeConfiguration(
                kind: kind, width: 17, height: 13, intensity: 1, pixelFormat: .rgba8Unorm, normalizesDensity: false)
            let a = try input.texture.c7.renderImageScope(extreme)
            let b = try midpoint.texture.c7.renderImageScope(normal)
            XCTAssertEqual(
                a.texture.c7.rawBytes(maximumBytes: 17 * 13 * 4), b.texture.c7.rawBytes(maximumBytes: 17 * 13 * 4))
        }
    }
}
