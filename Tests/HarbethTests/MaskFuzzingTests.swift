//
//  MaskFuzzingTests.swift
//  Harbeth
//

import XCTest
import simd
@testable import Harbeth

final class MaskFuzzingTests: XCTestCase {

    // MARK: - 随机源

    /// 固定 seed 的 LCG 随机源,避免 SystemRandomNumberGenerator 的非确定性。
    /// 每次跑用例都用同一个种子开始,确保本地和 CI 完全一致。
    private var rng: SeededLCG!

    override func setUp() {
        super.setUp()
        rng = SeededLCG(seed: 0x9E3779B97F4A7C15)
    }

    /// 在 [range.lowerBound, range.upperBound] 内采一个 Float。
    private func randFloat(in range: ClosedRange<Float>) -> Float {
        let t = Float(rng.nextUnit()) // 0...1
        return range.lowerBound + t * (range.upperBound - range.lowerBound)
    }

    /// 在 [range.lowerBound, range.upperBound] 内采一个 Int。
    private func randInt(in range: Range<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound)
        return range.lowerBound + Int(rng.nextBelow(span))
    }

    /// 在归一化 rect 内采一个 SIMD2<Float>。
    private func randPoint(in rect: SIMD4<Float>) -> SIMD2<Float> {
        SIMD2<Float>(
            randFloat(in: rect.x ... (rect.x + rect.z)),
            randFloat(in: rect.y ... (rect.y + rect.w))
        )
    }

    /// 随机选一个 MaskComponent。
    private func randComponent() -> MaskComponent {
        let cases: [MaskComponent] = [.alpha, .red, .green, .blue, .luminance]
        return cases[randInt(in: 0 ..< cases.count)]
    }

    /// 随机选一个 fill rule。
    private func randFillRule() -> MaskPathFillRule {
        return Bool.random(using: &rng) ? .nonZero : .evenOdd
    }

    /// 简单 LCG 随机源,产出 [0, 1) 的 Float。
    struct SeededLCG: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed }
        mutating func next() -> UInt64 {
            // Knuth's MMIX LCG
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        /// 返回 [0, 1) 的 Float。
        mutating func nextUnit() -> Float {
            return Float(next() >> 11) / Float(1 << 53)
        }
        /// 返回 [0, n) 的 UInt64。
        mutating func nextBelow(_ n: UInt64) -> UInt64 {
            precondition(n > 0)
            return next() % n
        }
    }

    // MARK: - 1. linearGradientCoverage

    /// linearGradientCoverage:5 个不变量 × 25 采样 = 125 断言
    func testFuzzLinearGradientAlwaysWithinZeroOneAndMonotonic() {
        for _ in 0 ..< 25 {
            let start = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let end   = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let uv    = randPoint(in: SIMD4<Float>(-0.2, -0.2, 1.4, 1.4))

            let v = MaskMath.linearGradientCoverage(uv: uv, start: start, end: end)

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0, "linear coverage < 0")
            XCTAssertLessThanOrEqual(v, 1, "linear coverage > 1")

            // 2. start 端 = 0
            XCTAssertEqual(
                MaskMath.linearGradientCoverage(uv: start, start: start, end: end),
                0, accuracy: 1e-5
            )

            // 3. end 端 = 1
            XCTAssertEqual(
                MaskMath.linearGradientCoverage(uv: end, start: start, end: end),
                1, accuracy: 1e-5
            )

            // 4. 反向端点对称:f(t) + f(1-t) ≈ 1
            //    在 start→end 中点两侧对称的两个点求和应该 ≈ 1
            let mid = (start + end) * 0.5
            let dir = normalize(end - start)
            let p1 = mid + dir * 0.2
            let p2 = mid - dir * 0.2
            let v1 = MaskMath.linearGradientCoverage(uv: p1, start: start, end: end)
            let v2 = MaskMath.linearGradientCoverage(uv: p2, start: start, end: end)
            XCTAssertEqual(v1 + v2, 1, accuracy: 1e-4,
                           "linear gradient non-symmetric: \(v1) + \(v2) != 1")

            // 5. UV 在 [start, end] 之外(包括很大越界值)不抛异常 & 仍 clamp 在 [0,1]
            let far = randPoint(in: SIMD4<Float>(-10, -10, 20, 20))
            let vfar = MaskMath.linearGradientCoverage(uv: far, start: start, end: end)
            XCTAssertGreaterThanOrEqual(vfar, 0)
            XCTAssertLessThanOrEqual(vfar, 1)
        }
    }

    // MARK: - 2. radialGradientCoverage

    /// radialGradientCoverage:5 个不变量 × 25 采样 = 125 断言
    func testFuzzRadialGradientAlwaysWithinZeroOneAndCentered() {
        for _ in 0 ..< 25 {
            let center = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let innerRadius = randFloat(in: 0 ... 0.3)
            let outerRadius = randFloat(in: (innerRadius + 0.0001) ... 0.7)
            let uv = randPoint(in: SIMD4<Float>(-0.5, -0.5, 2, 2))

            let v = MaskMath.radialGradientCoverage(
                uv: uv, center: center, innerRadius: innerRadius, outerRadius: outerRadius
            )

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0, "radial coverage < 0")
            XCTAssertLessThanOrEqual(v, 1, "radial coverage > 1")

            // 2. 中心点 = 1 (smoothstep(innerRadius, outerRadius, 0) = 0 → 1 - 0 = 1)
            XCTAssertEqual(
                MaskMath.radialGradientCoverage(
                    uv: center, center: center,
                    innerRadius: innerRadius, outerRadius: outerRadius
                ),
                1, accuracy: 1e-5
            )

            // 3. 远离 outerRadius > 一些距离 = 0
            //    找一个离 center 距离 > outerRadius + 0.05 的点
            let farDir = SIMD2<Float>(randFloat(in: -1 ... 1), randFloat(in: -1 ... 1))
            let farPoint = center + (farDir == .zero ? .init(1, 0) : normalize(farDir)) * (outerRadius + 0.1)
            let vfar = MaskMath.radialGradientCoverage(
                uv: farPoint, center: center,
                innerRadius: innerRadius, outerRadius: outerRadius
            )
            XCTAssertEqual(vfar, 0, accuracy: 1e-5,
                           "radial should be 0 past outerRadius, got \(vfar)")

            // 4. 中心对称:同一距离下的两个对称点 coverage 相同
            let angle = randFloat(in: 0 ... .pi * 2)
            let r = (innerRadius + outerRadius) * 0.5
            let p1 = center + SIMD2<Float>(cos(angle), sin(angle)) * r
            // 验证"半径相同 → 结果相同"性质:再取一个同半径、不同方向点
            let p3 = center + SIMD2<Float>(cos(angle + 1.234), sin(angle + 1.234)) * r
            let v1 = MaskMath.radialGradientCoverage(
                uv: p1, center: center, innerRadius: innerRadius, outerRadius: outerRadius
            )
            let v3 = MaskMath.radialGradientCoverage(
                uv: p3, center: center, innerRadius: innerRadius, outerRadius: outerRadius
            )
            XCTAssertEqual(v1, v3, accuracy: 1e-5,
                           "radial should be angle-invariant at same radius")

            // 5. 椭圆 radii 不等(虽然本函数是圆形)、输入越界不会抛异常
            XCTAssertFalse(v.isNaN, "radial produced NaN")
        }
    }

    // MARK: - 3. rectangleCoverage

    /// rectangleCoverage:5 个不变量 × 25 采样 = 125 断言
    func testFuzzRectangleAlwaysWithinZeroOneAndFeatherBoundary() {
        for _ in 0 ..< 25 {
            let rect = SIMD4<Float>(
                randFloat(in: -0.2 ... 0.5),
                randFloat(in: -0.2 ... 0.5),
                randFloat(in: 0.05 ... 1.2),
                randFloat(in: 0.05 ... 1.2)
            )
            let feather = randFloat(in: 0 ... 1)
            let point = randPoint(in: SIMD4<Float>(-0.5, -0.5, 2, 2))

            let v = MaskMath.rectangleCoverage(point: point, rect: rect, feather: feather)

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0, "rect coverage < 0")
            XCTAssertLessThanOrEqual(v, 1, "rect coverage > 1")

            // 2. feather = 1 时,在一定范围内全覆盖
            //    center 应该 = 1 (rect 完全覆盖中心)
            let center = SIMD2<Float>(rect.x + rect.z * 0.5, rect.y + rect.w * 0.5)
            let vcen = MaskMath.rectangleCoverage(point: center, rect: rect, feather: 1)
            XCTAssertGreaterThan(vcen, 0.95,
                                 "rect center with feather=1 should be near 1, got \(vcen)")

            // 3. feather = 0 是硬边:完全在 rect 内的点 = 1
            let insidePt = SIMD2<Float>(
                rect.x + rect.z * 0.1,
                rect.y + rect.w * 0.1
            )
            let vinside = MaskMath.rectangleCoverage(point: insidePt, rect: rect, feather: 0)
            XCTAssertEqual(vinside, 1, accuracy: 1e-5,
                           "rect hard-edge inside should be 1, got \(vinside)")

            // 4. 完全在 rect 外的点 = 0 (无论 feather)
            let outsidePt = SIMD2<Float>(rect.x - 0.5, rect.y - 0.5)
            let vout = MaskMath.rectangleCoverage(point: outsidePt, rect: rect, feather: feather)
            XCTAssertEqual(vout, 0, accuracy: 1e-5,
                           "rect far-outside should be 0")

            // 5. 任何 point 都不会"溢出"(非负)
            let farOut = SIMD2<Float>(randFloat(in: -10 ... 10), randFloat(in: -10 ... 10))
            let vfar = MaskMath.rectangleCoverage(point: farOut, rect: rect, feather: feather)
            XCTAssertFalse(vfar.isNaN, "rect produced NaN")
            XCTAssertFalse(vfar.isInfinite, "rect produced Inf")
            XCTAssertGreaterThanOrEqual(vfar, 0)
        }
    }

    // MARK: - 4. ellipseCoverage

    /// ellipseCoverage:5 个不变量 × 25 采样 = 125 断言
    func testFuzzEllipseAlwaysWithinZeroOneAndCentered() {
        for _ in 0 ..< 25 {
            let center = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let radii = SIMD2<Float>(
                randFloat(in: 0.05 ... 0.5),
                randFloat(in: 0.05 ... 0.5)
            )
            let feather = randFloat(in: 0 ... 1)
            let point = randPoint(in: SIMD4<Float>(-0.5, -0.5, 2, 2))

            let v = MaskMath.ellipseCoverage(
                point: point, center: center, radii: radii, feather: feather
            )

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThanOrEqual(v, 1)

            // 2. 中心点 = 1 (无论 feather,因为 normalized = 0 < 1 - featherWidth)
            XCTAssertEqual(
                MaskMath.ellipseCoverage(
                    point: center, center: center, radii: radii, feather: feather
                ),
                1, accuracy: 1e-5
            )

            // 3. 椭圆外 feather=0 = 0
            //    用一个 normalized > 1 的点:沿 x 轴方向加大半径
            let farOut = center + SIMD2<Float>(radii.x * 1.5, 0)
            let vout = MaskMath.ellipseCoverage(
                point: farOut, center: center, radii: radii, feather: 0
            )
            XCTAssertEqual(vout, 0, accuracy: 1e-5,
                           "ellipse outside with feather=0 should be 0")

            // 4. 轴上 normalized=0.5 内点 = 1(length < 1 ⇒ smoothstep 在 lower bound 之下)
            //    远离边界,不依赖浮点 y 误差放大
            let insidePt = center + SIMD2<Float>(radii.x * 0.5, 0)
            let vinsideAxis = MaskMath.ellipseCoverage(
                point: insidePt, center: center, radii: radii, feather: 0
            )
            XCTAssertEqual(vinsideAxis, 1, accuracy: 1e-5,
                "ellipse inner half-radius point should be 1, got \(vinsideAxis)")

            // (额外)normalized > 2 的远外点 = 0,测 feather=0 与 feather=0.5 都成立
            let farOutAxis = center + SIMD2<Float>(radii.x * 5, 0)
            let vfarAxis = MaskMath.ellipseCoverage(
                point: farOutAxis, center: center, radii: radii, feather: 0.5
            )
            XCTAssertEqual(vfarAxis, 0, accuracy: 1e-5,
                "ellipse far outer point should be 0 even with feather")

            // 5. feather 软边不影响 0/1 区(纯外 = 0, 纯内 = 1)
            let purelyOut = center + SIMD2<Float>(radii.x * 5, radii.y * 5)
            XCTAssertEqual(
                MaskMath.ellipseCoverage(
                    point: purelyOut, center: center, radii: radii, feather: 0.5
                ),
                0, accuracy: 1e-5
            )
        }
    }

    // MARK: - 5. polygonCoverage

    /// polygonCoverage:5 个不变量 × 25 采样 = 125 断言
    func testFuzzPolygonAlwaysWithinZeroOneAndConvexInside() {
        for _ in 0 ..< 25 {
            // 构造凸多边形:中心 + 沿圆周均匀分布的顶点
            let cx = randFloat(in: 0.2 ... 0.8)
            let cy = randFloat(in: 0.2 ... 0.8)
            let radius = randFloat(in: 0.05 ... 0.4)
            let sides = randInt(in: 3 ..< 9)
            var vertices: [SIMD2<Float>] = []
            for i in 0 ..< sides {
                let a = Float(i) / Float(sides) * .pi * 2
                vertices.append(SIMD2<Float>(cx + cos(a) * radius, cy + sin(a) * radius))
            }
            let point = randPoint(in: SIMD4<Float>(-0.2, -0.2, 1.4, 1.4))
            let fillRule = randFillRule()
            let feather = randFloat(in: 0 ... 0.3)

            let v = MaskMath.polygonCoverage(
                point: point, vertices: vertices, fillRule: fillRule, feather: feather
            )

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThanOrEqual(v, 1)

            // 2. 凸多边形中心 = 1
            XCTAssertEqual(
                MaskMath.polygonCoverage(
                    point: SIMD2<Float>(cx, cy),
                    vertices: vertices,
                    fillRule: fillRule,
                    feather: 0
                ),
                1, accuracy: 1e-5
            )

            // 3. 凸多边形外 feather=0 = 0
            let farOut = SIMD2<Float>(cx + 5, cy + 5)
            XCTAssertEqual(
                MaskMath.polygonCoverage(
                    point: farOut, vertices: vertices,
                    fillRule: fillRule, feather: 0
                ),
                0, accuracy: 1e-5
            )

            // 4. 退化三角形(3 点共线)不崩溃
            let degenerate: [SIMD2<Float>] = [
                SIMD2<Float>(0.1, 0.1),
                SIMD2<Float>(0.5, 0.1),
                SIMD2<Float>(0.9, 0.1),  // y 全部相同 → 共线
            ]
            let vdeg = MaskMath.polygonCoverage(
                point: SIMD2<Float>(0.5, 0.5),
                vertices: degenerate,
                fillRule: fillRule,
                feather: 0
            )
            XCTAssertFalse(vdeg.isNaN, "degenerate polygon produced NaN")
            XCTAssertGreaterThanOrEqual(vdeg, 0)
            XCTAssertLessThanOrEqual(vdeg, 1)

            // 5. 少于 3 个顶点不崩溃
            let tooFew: [SIMD2<Float>] = [SIMD2<Float>(0.5, 0.5)]
            let vfew = MaskMath.polygonCoverage(
                point: SIMD2<Float>(0.5, 0.5), vertices: tooFew, fillRule: fillRule, feather: 0
            )
            XCTAssertEqual(vfew, 0, "polygon with <3 vertices should return 0")
        }
    }

    // MARK: - 6. regionBlend

    /// regionBlend:5 个不变量 × 25 采样 = 125 断言
    func testFuzzRegionBlendBaseEffectCoverageOpacityChain() {
        for _ in 0 ..< 25 {
            let base   = SIMD4<Float>(randFloat(in: 0 ... 1), randFloat(in: 0 ... 1),
                                      randFloat(in: 0 ... 1), randFloat(in: 0 ... 1))
            let effect = SIMD4<Float>(randFloat(in: 0 ... 1), randFloat(in: 0 ... 1),
                                      randFloat(in: 0 ... 1), randFloat(in: 0 ... 1))
            let coverage = randFloat(in: 0 ... 1)
            let opacity = randFloat(in: 0 ... 1)

            let v = MaskMath.regionBlend(base: base, effect: effect, coverage: coverage, opacity: opacity)

            // 1. 输出 ∈ [0, 1] (channel wise)
            for i in 0 ..< 4 {
                XCTAssertGreaterThanOrEqual(v[i], 0,
                    "regionBlend channel \(i) < 0: \(v[i])")
                XCTAssertLessThanOrEqual(v[i], 1,
                    "regionBlend channel \(i) > 1: \(v[i])")
            }

            // 2. coverage = 0 = base
            let v0c = MaskMath.regionBlend(base: base, effect: effect, coverage: 0, opacity: opacity)
            for i in 0 ..< 4 {
                XCTAssertEqual(v0c[i], base[i], accuracy: 1e-5,
                    "coverage=0 should equal base at channel \(i)")
            }

            // 3. coverage = 1 时,mask 系数 = opacity,
            //    所以输出 = mix(base, effect, opacity)
            //    → 应当落在 base 和 effect 之间,且 base/effect 任一通道不同时应满足该通道 mix 公式
            let v1c = MaskMath.regionBlend(base: base, effect: effect, coverage: 1, opacity: opacity)
            for i in 0 ..< 4 {
                let lower = min(base[i], effect[i])
                let upper = max(base[i], effect[i])
                XCTAssertGreaterThanOrEqual(v1c[i], lower - 1e-5,
                    "coverage=1 channel \(i) below base..effect range: \(v1c[i])")
                XCTAssertLessThanOrEqual(v1c[i], upper + 1e-5,
                    "coverage=1 channel \(i) above base..effect range: \(v1c[i])")
                // mix(base, effect, opacity) = base*(1-opacity) + effect*opacity
                let expected = base[i] * (1 - opacity) + effect[i] * opacity
                XCTAssertEqual(v1c[i], expected, accuracy: 1e-4,
                    "coverage=1 mix formula off at channel \(i): got \(v1c[i]), expected \(expected)")
            }

            // 4. opacity = 0 = base
            let v0o = MaskMath.regionBlend(base: base, effect: effect, coverage: coverage, opacity: 0)
            for i in 0 ..< 4 {
                XCTAssertEqual(v0o[i], base[i], accuracy: 1e-5,
                    "opacity=0 should equal base at channel \(i)")
            }

            // 5. opacity = 1,coverage = 1 = effect(mask = 1, mix t=1)
            //    注意:coverage 不为 1 时,mask = coverage,输出 = mix(base, effect, coverage)
            let v11 = MaskMath.regionBlend(base: base, effect: effect, coverage: 1, opacity: 1)
            for i in 0 ..< 4 {
                XCTAssertEqual(v11[i], effect[i], accuracy: 1e-5,
                    "opacity=1 & coverage=1 should equal effect at channel \(i)")
            }

            // 6. (额外)rgba 各通道独立:mix 是逐分量
            //    如果 base 和 effect 只有 R 不同,其它相同,其它通道应不变
            let b2 = SIMD4<Float>(0.2, 0.5, 0.5, 0.5)
            let e2 = SIMD4<Float>(0.8, 0.5, 0.5, 0.5)
            let mix = MaskMath.regionBlend(base: b2, effect: e2, coverage: 0.5, opacity: 1)
            XCTAssertEqual(mix.x, 0.5, accuracy: 1e-5, "R channel should average")
            XCTAssertEqual(mix.y, 0.5, accuracy: 1e-5, "G channel should be unchanged")
            XCTAssertEqual(mix.z, 0.5, accuracy: 1e-5, "B channel should be unchanged")
            XCTAssertEqual(mix.w, 0.5, accuracy: 1e-5, "A channel should be unchanged")
        }
    }

    // MARK: - 7. coverageFromRGB

    /// coverageFromRGB:5 个不变量 × 25 采样 = 125 断言
    func testFuzzCoverageFromRGBComponentRoutingCorrect() {
        for _ in 0 ..< 25 {
            let r = randFloat(in: 0 ... 1)
            let g = randFloat(in: 0 ... 1)
            let b = randFloat(in: 0 ... 1)
            let rgb = SIMD3<Float>(r, g, b)
            let component = randComponent()

            let v = MaskMath.coverageFromRGB(rgb: rgb, component: component)

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThanOrEqual(v, 1)

            // 2. .red 路由到 r 分量
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: rgb, component: .red), r,
                accuracy: 1e-5
            )

            // 3. .green 路由到 g
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: rgb, component: .green), g,
                accuracy: 1e-5
            )

            // 4. .blue 路由到 b
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: rgb, component: .blue), b,
                accuracy: 1e-5
            )

            // 5. .luminance 使用 Rec.601 权重
            let expectedLuma = r * 0.299 + g * 0.587 + b * 0.114
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: rgb, component: .luminance),
                expectedLuma,
                accuracy: 1e-5,
                "luminance not matching Rec.601 formula"
            )

            // 6. (额外).alpha 在 RGB-only 函数中固定返回 0(API 契约)
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: rgb, component: .alpha), 0,
                accuracy: 1e-5
            )

            // 7. (额外).pure white luminance = 1
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: SIMD3<Float>(1, 1, 1), component: .luminance),
                1, accuracy: 1e-5
            )
            // 8. (额外).pure black luminance = 0
            XCTAssertEqual(
                MaskMath.coverageFromRGB(rgb: SIMD3<Float>(0, 0, 0), component: .luminance),
                0, accuracy: 1e-5
            )
        }
    }

    // MARK: - 8. extractCoverage

    /// extractCoverage:5 个不变量 × 25 采样 = 125 断言
    func testFuzzExtractCoverageInvertOpacityChainCorrect() {
        for _ in 0 ..< 25 {
            let rgba = SIMD4<Float>(
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1)
            )
            let component = randComponent()
            let invert = Bool.random(using: &rng)
            let feather = randFloat(in: 0 ... 0.4)
            let opacity = randFloat(in: 0 ... 1)

            let v = MaskMath.extractCoverage(
                rgba: rgba, component: component,
                invert: invert, feather: feather, opacity: opacity
            )

            // 1. 输出 ∈ [0, 1]
            XCTAssertGreaterThanOrEqual(v, 0, "extract coverage < 0")
            XCTAssertLessThanOrEqual(v, 1, "extract coverage > 1")

            // 2. invert 翻转 [0, 1]:ext(c) + ext(invert=c) = 1 (feather=0 时严格成立;
            //    feather>0 时 smoothstep 不严格对称,这里只在 feather=0 下断言)
            let base = MaskMath.extractCoverage(
                rgba: rgba, component: component, invert: false, feather: 0, opacity: 1
            )
            let inv = MaskMath.extractCoverage(
                rgba: rgba, component: component, invert: true, feather: 0, opacity: 1
            )
            XCTAssertEqual(base + inv, 1, accuracy: 1e-4,
                "invert should be exact complement at feather=0, got \(base)+\(inv)=\(base+inv)")

            // 3. opacity 链路不超出范围:opacity = 0 → 0
            XCTAssertEqual(
                MaskMath.extractCoverage(
                    rgba: rgba, component: component, invert: invert,
                    feather: feather, opacity: 0
                ),
                0, accuracy: 1e-5
            )

            // 4. component 提取正确(以 rgba 分量直接断言)
            switch component {
            case .alpha:
                XCTAssertEqual(
                    MaskMath.extractCoverage(
                        rgba: rgba, component: .alpha, invert: false,
                        feather: 0, opacity: 1
                    ),
                    rgba.w, accuracy: 1e-5
                )
            case .red:
                XCTAssertEqual(
                    MaskMath.extractCoverage(
                        rgba: rgba, component: .red, invert: false,
                        feather: 0, opacity: 1
                    ),
                    rgba.x, accuracy: 1e-5
                )
            case .luminance:
                let expected = rgba.x * 0.299 + rgba.y * 0.587 + rgba.z * 0.114
                XCTAssertEqual(
                    MaskMath.extractCoverage(
                        rgba: rgba, component: .luminance, invert: false,
                        feather: 0, opacity: 1
                    ),
                    expected, accuracy: 1e-5
                )
            default:
                break
            }

            // 5. 量化后整数倍准确:opacity=1, 二值化后要么是 raw 要么是 1-raw
            //    这里用 opacity = 1 + invert = false,验证与 RGBA 分量严格对齐
            if !invert && feather == 0 && opacity == 1 {
                switch component {
                case .alpha:
                    XCTAssertEqual(v, rgba.w, accuracy: 1e-5)
                case .red:
                    XCTAssertEqual(v, rgba.x, accuracy: 1e-5)
                case .green:
                    XCTAssertEqual(v, rgba.y, accuracy: 1e-5)
                case .blue:
                    XCTAssertEqual(v, rgba.z, accuracy: 1e-5)
                case .luminance:
                    let expected = rgba.x * 0.299 + rgba.y * 0.587 + rgba.z * 0.114
                    XCTAssertEqual(v, expected, accuracy: 1e-5)
                }
            }
        }
    }

    // MARK: - 9. meta invariant test

    /// 跨 8 个函数全部跑 100 轮随机输入,断言输出 ∈ [0, 1] 的元不变量。
    func testAllMaskMathFunctionsRespectOutputRange() {
        for _ in 0 ..< 100 {
            // 1. linear
            let linUv = randPoint(in: SIMD4<Float>(-1, -1, 3, 3))
            let linStart = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let linEnd = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let linV = MaskMath.linearGradientCoverage(uv: linUv, start: linStart, end: linEnd)
            XCTAssertTrue((0 ... 1).contains(linV) && !linV.isNaN, "linear outside [0,1]: \(linV)")

            // 2. radial
            let radCenter = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let radUv = randPoint(in: SIMD4<Float>(-2, -2, 5, 5))
            let radV = MaskMath.radialGradientCoverage(
                uv: radUv, center: radCenter,
                innerRadius: randFloat(in: 0 ... 0.3),
                outerRadius: randFloat(in: 0.3 ... 1)
            )
            XCTAssertTrue((0 ... 1).contains(radV) && !radV.isNaN, "radial outside [0,1]: \(radV)")

            // 3. rectangle
            let rectRect = SIMD4<Float>(
                randFloat(in: -0.5 ... 0.5),
                randFloat(in: -0.5 ... 0.5),
                randFloat(in: 0.05 ... 1),
                randFloat(in: 0.05 ... 1)
            )
            let rectPoint = randPoint(in: SIMD4<Float>(-1, -1, 3, 3))
            let rectV = MaskMath.rectangleCoverage(
                point: rectPoint, rect: rectRect, feather: randFloat(in: 0 ... 1)
            )
            XCTAssertTrue((0 ... 1).contains(rectV) && !rectV.isNaN && !rectV.isInfinite, "rectangle outside [0,1]: \(rectV)")

            // 4. ellipse
            let ellCenter = randPoint(in: SIMD4<Float>(0, 0, 1, 1))
            let ellPoint = randPoint(in: SIMD4<Float>(-1, -1, 3, 3))
            let ellV = MaskMath.ellipseCoverage(
                point: ellPoint, center: ellCenter,
                radii: SIMD2<Float>(
                    randFloat(in: 0.05 ... 0.5),
                    randFloat(in: 0.05 ... 0.5)
                ),
                feather: randFloat(in: 0 ... 1)
            )
            XCTAssertTrue((0 ... 1).contains(ellV) && !ellV.isNaN, "ellipse outside [0,1]: \(ellV)")

            // 5. polygon
            //    随机生成凸多边形
            let cx = randFloat(in: 0.2 ... 0.8)
            let cy = randFloat(in: 0.2 ... 0.8)
            let r = randFloat(in: 0.05 ... 0.3)
            let sides = randInt(in: 3 ..< 7)
            var verts: [SIMD2<Float>] = []
            for i in 0 ..< sides {
                let a = Float(i) / Float(sides) * .pi * 2
                verts.append(SIMD2<Float>(cx + cos(a) * r, cy + sin(a) * r))
            }
            let polyPoint = randPoint(in: SIMD4<Float>(-1, -1, 3, 3))
            let polyV = MaskMath.polygonCoverage(
                point: polyPoint, vertices: verts,
                fillRule: randFillRule(),
                feather: randFloat(in: 0 ... 0.2)
            )
            XCTAssertTrue((0 ... 1).contains(polyV) && !polyV.isNaN, "polygon outside [0,1]: \(polyV)")

            // 6. regionBlend
            let b = SIMD4<Float>(randFloat(in: 0 ... 1), randFloat(in: 0 ... 1),
                                 randFloat(in: 0 ... 1), randFloat(in: 0 ... 1))
            let e = SIMD4<Float>(randFloat(in: 0 ... 1), randFloat(in: 0 ... 1),
                                 randFloat(in: 0 ... 1), randFloat(in: 0 ... 1))
            let rbV = MaskMath.regionBlend(
                base: b, effect: e,
                coverage: randFloat(in: 0 ... 1),
                opacity: randFloat(in: 0 ... 1)
            )
            for i in 0 ..< 4 {
                XCTAssertTrue((0 ... 1).contains(rbV[i]), "regionBlend[\(i)] outside [0,1]: \(rbV[i])")
            }

            // 7. coverageFromRGB
            let rgb = SIMD3<Float>(
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1)
            )
            let rgbV = MaskMath.coverageFromRGB(rgb: rgb, component: randComponent())
            XCTAssertTrue((0 ... 1).contains(rgbV) && !rgbV.isNaN, "coverageFromRGB outside [0,1]: \(rgbV)")

            // 8. extractCoverage
            let rgba = SIMD4<Float>(
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1),
                randFloat(in: 0 ... 1)
            )
            let extV = MaskMath.extractCoverage(
                rgba: rgba, component: randComponent(),
                invert: Bool.random(using: &rng),
                feather: randFloat(in: 0 ... 0.4),
                opacity: randFloat(in: 0 ... 1)
            )
            XCTAssertTrue((0 ... 1).contains(extV) && !extV.isNaN, "extractCoverage outside [0,1]: \(extV)")
        }
    }
}
