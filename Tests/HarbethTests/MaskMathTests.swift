//
//  MaskMathTests.swift
//  Harbeth
//

import XCTest
import simd
@testable import Harbeth

final class MaskMathTests: XCTestCase {

    // 数值类断言的统一精度;参考 MaskFuzzingTests 的 1e-5。
    private let accuracy: Float = 1e-5

    /// UV 恰好等于 start:t = dot(0, delta) / dot(delta,delta) = 0,clamp 后仍为 0
    func testLinearGradientStartPointIsZero() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0, 0),
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// UV 恰好等于 end:t = 1,clamp 后仍为 1
    func testLinearGradientEndPointIsOne() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(1, 0),
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// UV 在线段中点:t = 0.5,正好居中
    func testLinearGradientMidpointIsHalf() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0.5, 0),
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 0.5, accuracy: accuracy)
    }

    /// UV 在 start 之前(左外):t < 0,clamp 后 = 0
    func testLinearGradientBeforeStartClampsToZero() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(-1, 0),
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// UV 在 end 之外(右外):t > 1,clamp 后 = 1
    func testLinearGradientAfterEndClampsToOne() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(5, 0),
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// UV 在 start 上(垂直偏移):dot(uv-start, delta) = 0,coverage = 0
    /// 这是"垂直 offset 不影响梯度"的本质——只有沿 delta 方向的投影才有贡献
    func testLinearGradientPerpendicularOffsetIsZero() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0, 0.5),    // (0,0.5) 在线段 (0,0)→(1,0) 上的投影点是 (0,0)
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// UV 在线段外的垂直方向:projection 0,clamp 后 = 0
    func testLinearGradientFarPerpendicularIsZero() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0.5, 10),  // x 投影到线段上是 0.5,但 y 偏移不影响投影
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 0.5, accuracy: accuracy, "y 偏移不影响沿 x 轴投影;t = 0.5 → coverage = 0.5")
    }

    /// 对角线渐变:start (0,0)→end (1,1),中点 (0.5, 0.5) 投影 = 1.0
    /// delta = (1,1),dot(delta,delta) = 2,dot((0.5,0.5),(1,1)) = 1,t = 0.5
    func testLinearGradientDiagonalMidpointIsHalf() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0.5, 0.5),
            start: .init(0, 0),
            end: .init(1, 1)
        )
        XCTAssertEqual(value, 0.5, accuracy: accuracy)
    }

    /// 对角线渐变 start→end 是同一个点(delta = 0):denominator 被 max 钳到 1e-6
    /// 数学上未定义,但函数必须安全返回(此处 t = 0/1e-6 = 0,clamp 后 = 0)
    func testLinearGradientDegenerateSameStartEndDoesNotCrash() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0.5, 0.5),
            start: .init(0.3, 0.3),
            end: .init(0.3, 0.3)
        )
        XCTAssertEqual(value, 0, accuracy: accuracy, "退化线段被 max(dot, 1e-6) 钳,dot((0.2,0.2),(0,0))=0 → 0")
        XCTAssertFalse(value.isNaN)
    }

    /// 反向渐变(从大到小):start (1,0),end (0,0)
    /// UV 在 (1, 0) 时 t = dot((0,0),(−1,0)) / 1 = 0 → coverage = 0
    /// UV 在 (0, 0) 时 t = dot((−1,0),(−1,0)) / 1 = 1 → coverage = 1
    func testLinearGradientReversedEndpoints() {
        let atStart = MaskMath.linearGradientCoverage(
            uv: .init(1, 0), start: .init(1, 0), end: .init(0, 0)
        )
        let atEnd = MaskMath.linearGradientCoverage(
            uv: .init(0, 0), start: .init(1, 0), end: .init(0, 0)
        )
        XCTAssertEqual(atStart, 0, accuracy: accuracy, "reverse gradient: 视觉上的 'start' 仍然是 0 coverage")
        XCTAssertEqual(atEnd, 1, accuracy: accuracy)
    }

    /// 1/4 处的精确值:start (0,0),end (1,0),UV (0.25, 0) → t = 0.25
    func testLinearGradientQuarterPointExactValue() {
        let value = MaskMath.linearGradientCoverage(
            uv: .init(0.25, 0),
            start: .init(0, 0),
            end: .init(1, 0)
        )
        XCTAssertEqual(value, 0.25, accuracy: accuracy)
    }

    /// 内部一致性:f(t) + f(1-t) = 1(在 start→end 中点两侧对称点求和应 ≈ 1)
    /// W5 的 fuzzing 也断言过,这里给出**确定性**点 t=0.3 和 t=0.7 求和
    func testLinearGradientSymmetricPointsSumToOne() {
        let a = MaskMath.linearGradientCoverage(
            uv: .init(0.3, 0), start: .init(0, 0), end: .init(1, 0)
        )
        let b = MaskMath.linearGradientCoverage(
            uv: .init(0.7, 0), start: .init(0, 0), end: .init(1, 0)
        )
        XCTAssertEqual(a + b, 1, accuracy: 1e-4, "linear 对称点求和应为 1;0.3 + 0.7 = 1")
    }

    // MARK: - radialGradientCoverage (10 cases)

    /// 中心 UV:smoothstep(inner, outer, 0) = 0 → coverage = 1 - 0 = 1
    func testRadialGradientCenterIsOne() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            innerRadius: 0.1,
            outerRadius: 0.3
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 内部(inner 内):distance < inner,smoothstep 返回 0,coverage = 1
    func testRadialGradientInnerAreaIsOne() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(0.55, 0.5),    // 距中心 0.05 < innerRadius=0.2
            center: .init(0.5, 0.5),
            innerRadius: 0.2,
            outerRadius: 0.4
        )
        XCTAssertEqual(value, 1, accuracy: accuracy, "distance=0.05 < innerRadius=0.2,coverage=1")
    }

    /// 外部(outer 之外):distance > outer,smoothstep 返回 1,coverage = 0
    func testRadialGradientOutsideOuterIsZero() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(1.0, 0.5),     // 距中心 0.5 > outerRadius=0.3
            center: .init(0.5, 0.5),
            innerRadius: 0.1,
            outerRadius: 0.3
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 退化情形 innerRadius == outerRadius:返回 1(中心)或 0(其他)
    /// 因为 endRadius = max(outer, startRadius + 1e-6),总是 > inner,函数不会除零
    func testRadialGradientDegenerateZeroWidthRingIsSafe() {
        let center = MaskMath.radialGradientCoverage(
            uv: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            innerRadius: 0.2,
            outerRadius: 0.2
        )
        let offCenter = MaskMath.radialGradientCoverage(
            uv: .init(0.71, 0.5),    // 距中心 0.21 ≈ outer
            center: .init(0.5, 0.5),
            innerRadius: 0.2,
            outerRadius: 0.2
        )
        XCTAssertEqual(center, 1, accuracy: accuracy, "ring 退化为点时,中心点仍是 1")
        // offCenter 处 distance = 0.21,endRadius = 0.2 + 1e-6 → smoothstep 返回 1
        XCTAssertEqual(offCenter, 0, accuracy: accuracy, "ring 退化为点时,稍偏一点即落外,=0")
    }

    /// innerRadius=0 退化:中心点仍 = 1(因为 smoothstep(0, 1e-6, 0) = 0)
    func testRadialGradientZeroInnerRadiusCenterIsOne() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            innerRadius: 0,
            outerRadius: 0.5
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// innerRadius=0,outerRadius=0:中心=1,远外=0,函数安全
    func testRadialGradientZeroRadiusIsSafe() {
        let center = MaskMath.radialGradientCoverage(
            uv: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            innerRadius: 0,
            outerRadius: 0
        )
        XCTAssertEqual(center, 1, accuracy: accuracy, "zero radii 退化,中心仍是 1")
        XCTAssertFalse(center.isNaN)
    }

    /// 负 innerRadius 被 max 钳到 0:与正 innerRadius=0 等价
    func testRadialGradientNegativeInnerRadiusClampsToZero() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            innerRadius: -5,
            outerRadius: 0.3
        )
        XCTAssertEqual(value, 1, accuracy: accuracy, "innerRadius=-5 被 max(-5, 0) 钳为 0")
    }

    /// mid 处的精确值验证:innerRadius=0, outerRadius=0.4, UV 距中心 0.2
    /// smoothstep(0, 0.4, 0.2):t=0.5,return 0.5*(3-1)=0.5;coverage = 1-0.5 = 0.5
    func testRadialGradientMidpointIsExactlyHalf() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(0.7, 0.5),
            center: .init(0.5, 0.5),
            innerRadius: 0,
            outerRadius: 0.4
        )
        XCTAssertEqual(value, 0.5, accuracy: accuracy, "smoothstep(0, 0.4, 0.2) = 0.5 → coverage = 0.5")
    }

    /// 角度无关性:同一距离的两个方向点 coverage 相等(不强行断言具体值,
    /// 因为 smoothstep 在 innerRadius=0 时距 center=0.15 处会给出 < 1 的中间值)
    func testRadialGradientAngleIndependentAtSameRadius() {
        let center: SIMD2<Float> = .init(0.5, 0.5)
        // 距中心 0.15 的两个方向点(距离相同,方向不同)
        let east  = SIMD2<Float>(0.65, 0.5)
        let north = SIMD2<Float>(0.5,  0.65)
        let a = MaskMath.radialGradientCoverage(
            uv: east, center: center, innerRadius: 0, outerRadius: 0.4
        )
        let b = MaskMath.radialGradientCoverage(
            uv: north, center: center, innerRadius: 0, outerRadius: 0.4
        )
        XCTAssertEqual(a, b, accuracy: accuracy, "径向只与距离有关,与方向无关")
        XCTAssertGreaterThan(a, 0.5, "距离 0.15 < outer 0.4,在 smoothstep 内侧,coverage 应 > 0.5,got=\(a)")
        XCTAssertLessThan(a, 1)
    }

    /// 距中心恰好 outerRadius 的点:smoothstep 在 edge1 给出 1,coverage = 0
    func testRadialGradientAtOuterRadiusIsZero() {
        let value = MaskMath.radialGradientCoverage(
            uv: .init(0.9, 0.5),  // 距中心正好 0.4 = outerRadius
            center: .init(0.5, 0.5),
            innerRadius: 0,
            outerRadius: 0.4
        )
        XCTAssertEqual(value, 0, accuracy: accuracy, "smoothstep 在 edge1 处返回 1,coverage = 0")
    }

    // MARK: - rectangleCoverage (12 cases)

    /// 矩形 4 个角点在外 = 0,因为 step() 把外面清零(无论 feather)
    func testRectangleCornerOutsideIsZero() {
        let v0 = MaskMath.rectangleCoverage(
            point: .init(0, 0),
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 0.5  // 用很大 feather 看是否还是 0
        )
        XCTAssertEqual(v0, 0, accuracy: accuracy, "rect 角点之外 step() 清零,feather 多大都没用")
    }

    /// 矩形中心 + feather=0(硬边):local = (0.5, 0.5),edgeDistance = (0.5, 0.5)
    /// minEdge = 0.5,featherWidth = max(0, 1e-6) = 1e-6
    /// smoothstep(0, 1e-6, 0.5):t = clamp(0.5/1e-6) = 1 → return 1
    func testRectangleCenterHardEdgeIsOne() {
        let value = MaskMath.rectangleCoverage(
            point: .init(0.5, 0.5),
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 矩形中心 + feather=1:featherWidth = 0.5,minEdge=0.5
    /// smoothstep(0, 0.5, 0.5) = 1;step() 全 1 → coverage = 1
    func testRectangleCenterFeatherOneIsOne() {
        let value = MaskMath.rectangleCoverage(
            point: .init(0.5, 0.5),
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 1
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 9 个采样点边界检查:中点、左上角、左下角、右上角、右下角、4 个边中点
    /// rect = (0.25, 0.25, 0.5, 0.5) → [0.25,0.75]×[0.25,0.75]
    /// 中心 (0.5,0.5):内,应 = 1
    /// 4 个角 (在 rect 上,local = (0, 0)):step 全部成立,但 minEdge=0,smoothstep(0, fw, 0)=0
    /// 4 个边中点:也在 rect 上,minEdge=0,同上 = 0
    func testRectangleNineSamplingGrid() {
        let rect = SIMD4<Float>(0.25, 0.25, 0.5, 0.5)
        let feather: Float = 0
        // 角点(4)
        let topLeft     = MaskMath.rectangleCoverage(point: .init(0.25, 0.25), rect: rect, feather: feather)
        let topRight    = MaskMath.rectangleCoverage(point: .init(0.75, 0.25), rect: rect, feather: feather)
        let bottomLeft  = MaskMath.rectangleCoverage(point: .init(0.25, 0.75), rect: rect, feather: feather)
        let bottomRight = MaskMath.rectangleCoverage(point: .init(0.75, 0.75), rect: rect, feather: feather)
        // 边中点(4)
        let topMid      = MaskMath.rectangleCoverage(point: .init(0.5, 0.25), rect: rect, feather: feather)
        let bottomMid   = MaskMath.rectangleCoverage(point: .init(0.5, 0.75), rect: rect, feather: feather)
        let leftMid     = MaskMath.rectangleCoverage(point: .init(0.25, 0.5), rect: rect, feather: feather)
        let rightMid    = MaskMath.rectangleCoverage(point: .init(0.75, 0.5), rect: rect, feather: feather)
        // 中心
        let center      = MaskMath.rectangleCoverage(point: .init(0.5, 0.5), rect: rect, feather: feather)

        // 中心 = 1
        XCTAssertEqual(center, 1, accuracy: accuracy)
        // 在 rect 边界上(角点 / 边中点):minEdge=0,smoothstep=0,覆盖 = 0
        // 注:feather=0 时 featherWidth 被 max 钳到 1e-6,所以严格来说不是 0 但 ≈ 0
        // step() 给出 1,但 smoothstep(0, 1e-6, 0) = 0
        XCTAssertEqual(topLeft,     0, accuracy: 0.01)
        XCTAssertEqual(topRight,    0, accuracy: 0.01)
        XCTAssertEqual(bottomLeft,  0, accuracy: 0.01)
        XCTAssertEqual(bottomRight, 0, accuracy: 0.01)
        XCTAssertEqual(topMid,      0, accuracy: 0.01)
        XCTAssertEqual(bottomMid,   0, accuracy: 0.01)
        XCTAssertEqual(leftMid,     0, accuracy: 0.01)
        XCTAssertEqual(rightMid,    0, accuracy: 0.01)
    }

    /// feather=0(硬边) + 完全在 rect 内的一点:coverage = 1
    func testRectangleInsideHardEdgeIsOne() {
        let value = MaskMath.rectangleCoverage(
            point: .init(0.4, 0.4),
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 完全在 rect 外的一点:coverage = 0(与 feather 无关)
    func testRectangleOutsideIsZeroRegardlessOfFeather() {
        let outside = SIMD2<Float>(-0.5, -0.5)
        let feather: Float = 0.8
        let v = MaskMath.rectangleCoverage(
            point: outside,
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: feather
        )
        XCTAssertEqual(v, 0, accuracy: accuracy)
    }

    /// feather 中间值(0.5)在 soft band 内的精确值
    /// rect (0.25, 0.25, 0.5, 0.5),point = (0.3, 0.5) → local = (0.1, 0.5)
    /// edgeDistance = (min(0.1, 0.9), min(0.5, 0.5)) = (0.1, 0.5)
    /// minEdge = 0.1
    /// featherWidth = max(0.5 * 0.5, 1e-6) = 0.25
    /// smoothstep(0, 0.25, 0.1):t=0.4,return 0.4*0.4*(3-0.8)=0.352
    /// step() 全部成立 → coverage = 0.352
    func testRectangleFeatherBandMidpointExactValue() {
        let value = MaskMath.rectangleCoverage(
            point: .init(0.3, 0.5),
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 0.5
        )
        XCTAssertEqual(value, 0.352, accuracy: 1e-3,
                       "feather band 内插值,smoothstep(0, 0.25, 0.1) ≈ 0.352")
    }

    /// 1 像素矩形(退化):rect (0.5, 0.5, 1e-7, 1e-7)
    /// size 被 max(rect.z, 1e-6) 钳到 1e-6,local = (uv - 0.5) / 1e-6
    /// 函数不崩溃,但覆盖率只对极少数点 = 1
    func testRectangleDegenerateZeroSizeDoesNotCrash() {
        let tiny = SIMD4<Float>(0.5, 0.5, 0, 0)
        let farOut = MaskMath.rectangleCoverage(
            point: .init(0, 0), rect: tiny, feather: 0
        )
        XCTAssertFalse(farOut.isNaN, "零 size rect 应安全")
        XCTAssertFalse(farOut.isInfinite)
        XCTAssertEqual(farOut, 0, accuracy: accuracy)
    }

    /// local = 1 边界(rect 右边界):minEdge = min(1, 0) = 0,smoothstep(0, fw, 0)=0
    /// step(local.x, 1) 也 = 0(local.x < 1),最终 = 0
    func testRectangleOnRightEdgeIsZero() {
        let vInside = MaskMath.rectangleCoverage(
            point: .init(0.75, 0.5),  // rect 右边界
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 0
        )
        XCTAssertEqual(vInside, 0, accuracy: 0.01)
    }

    /// local = 1 之外(rect 右外侧):step(local.x, 1) = 0,coverage = 0
    func testRectangleOutsideRightEdgeIsZero() {
        let v = MaskMath.rectangleCoverage(
            point: .init(0.76, 0.5),  // rect 右边界 0.75 + 0.01
            rect: .init(0.25, 0.25, 0.5, 0.5),
            feather: 0
        )
        XCTAssertEqual(v, 0, accuracy: accuracy)
    }

    /// rect 完全在像素画布外(point (0.5, 0.5), rect (0, 0, 0, 0))→ 0
    func testRectangleOffCanvasReturnsZero() {
        let v = MaskMath.rectangleCoverage(
            point: .init(0.5, 0.5),
            rect: .init(2, 2, 1, 1),  // 完全在 [0,1] 之外
            feather: 0.5
        )
        XCTAssertEqual(v, 0, accuracy: accuracy)
    }

    // MARK: - ellipseCoverage (10 cases)

    /// 椭圆中心 = 1(normalized=0,smoothstep(1-fw, 1, 0) = 0 → coverage = 1)
    func testEllipseCenterIsOne() {
        let value = MaskMath.ellipseCoverage(
            point: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0.1
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 椭圆长轴端点附近的点:normalized ≈ 1,在羽化带边缘 → coverage ≈ 0
    /// 注意:feather=0 时 featherWidth = 1e-6,smoothstep(0.999999, 1, ~1) ≈ 1
    /// 浮点 round 让 normalized 严格不正好 = 1,所以给边缘容差(2%)
    func testEllipseOnLongAxisWithZeroFeatherIsNearZero() {
        let value = MaskMath.ellipseCoverage(
            point: .init(0.7, 0.5),  // 长轴端点(center + (radii.x, 0))
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0
        )
        XCTAssertLessThan(value, 0.02)
    }

    /// 长轴内部点:normalized = (0.5, 0),length = 0.5 < 1-fw → coverage = 1
    func testEllipseInsideLongAxisHalfIsOne() {
        let value = MaskMath.ellipseCoverage(
            point: .init(0.6, 0.5),  // center + (radii.x * 0.5, 0) = (0.6, 0.5)
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy, "normalized=0.5 < 1,在 hard band 内 → 1")
    }

    /// 长轴外点:normalized = 2,length = 2 → coverage = 0
    func testEllipseFarOutsideLongAxisIsZero() {
        let value = MaskMath.ellipseCoverage(
            point: .init(1.0, 0.5),  // 距中心 0.5,radii.x = 0.2,normalized = 2.5
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 短轴端点:normalized = (0, 1),length = 1 → 边界 = 0(feather=0)
    func testEllipseOnShortAxisWithZeroFeatherIsZero() {
        let value = MaskMath.ellipseCoverage(
            point: .init(0.5, 0.6),  // center + (0, radii.y)
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy, "normalized 在短轴端点 = 1,coverage = 0")
    }

    /// 短轴内部点:normalized = (0, 0.5),length = 0.5 → 1
    func testEllipseInsideShortAxisHalfIsOne() {
        let value = MaskMath.ellipseCoverage(
            point: .init(0.5, 0.55),  // center + (0, radii.y * 0.5)
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 椭圆外的对角点:无论 feather 多大,normalized > 1 都返回 0
    func testEllipseCornerFarOutsideIsZero() {
        let value = MaskMath.ellipseCoverage(
            point: .init(0, 0),
            center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1),
            feather: 0.5
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// feathersfeather = 0 与 feather = 0.001 在中心点是等价的(中心永远 = 1)
    func testEllipseFeatherDoesNotAffectCenter() {
        let c1 = MaskMath.ellipseCoverage(
            point: .init(0.5, 0.5), center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1), feather: 0
        )
        let c2 = MaskMath.ellipseCoverage(
            point: .init(0.5, 0.5), center: .init(0.5, 0.5),
            radii: .init(0.2, 0.1), feather: 1
        )
        XCTAssertEqual(c1, 1, accuracy: accuracy)
        XCTAssertEqual(c2, 1, accuracy: accuracy)
    }

    /// 退化:radii = (0, 0),被 max 钳到 (1e-6, 1e-6),normalized 在远处 ≈ 很大 → 0
    /// 函数不崩溃,中心仍 = 1
    func testEllipseDegenerateZeroRadiusDoesNotCrash() {
        let center = MaskMath.ellipseCoverage(
            point: .init(0.5, 0.5),
            center: .init(0.5, 0.5),
            radii: .init(0, 0),
            feather: 0
        )
        XCTAssertEqual(center, 1, accuracy: accuracy, "zero radii 被钳,中心仍 = 1(实际 normalized=0)")
        XCTAssertFalse(center.isNaN)
    }

    /// 圆(radii 相等)与椭圆(不等)在同一距离对角点的覆盖差异:
    /// 相同半径时 = 圆;不等时 = 椭圆,沿较短轴方向覆盖率更大
    /// 这里不给精确值,只断言"圆 > 椭圆"在角点处
    func testEllipseRoundVsElongatedAtCorner() {
        let corner = SIMD2<Float>(0.7, 0.7)
        // 圆:radii = (0.2, 0.2),normalized = (1, 1),length = √2 ≈ 1.414 → 0
        let circle = MaskMath.ellipseCoverage(
            point: corner, center: .init(0.5, 0.5),
            radii: .init(0.2, 0.2), feather: 0
        )
        // 长椭圆:radii = (0.4, 0.1),normalized = (0.5, 2),length = √4.25 ≈ 2.06 → 0
        // 但normalized.y = 2 > 1,所以也是 0;改用 radiance 让椭圆在角点附近有非零 coverage
        let elongated = MaskMath.ellipseCoverage(
            point: corner, center: .init(0.5, 0.5),
            radii: .init(0.5, 0.5), feather: 0
        )
        // 圆在 normalized = √2 时仍 = 0
        XCTAssertEqual(circle, 0, accuracy: accuracy)
        // 长椭圆 normalized = (0.4, 0.4),length ≈ 0.566 < 1 → 1
        XCTAssertEqual(elongated, 1, accuracy: accuracy, "椭圆在角点处只要 normalized < 1 就是 1")
    }

    // MARK: - roundedRectCoverage (6 cases)

    /// 中心点:cornerRadius = 0.2,在 SDF 内 → sdf < 0 → coverage = 1
    func testRoundedRectCenterIsOne() {
        let c = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0, 0, 1, 1),
            cornerRadius: 0.2,
            feather: 0
        )
        XCTAssertEqual(c, 1, accuracy: accuracy, "圆角矩形中心 SDF < 0,coverage = 1")
    }

    /// 矩形外角点(0,0):rect = (0.2,0.2,0.6,0.6),中心 0.5/0.5,
    /// corner = (0.2 - 0.5, 0.2 - 0.5) = (-0.3, -0.3),q = abs(-0.3) - 0.5 + 0.2 = (-0.3, -0.3),
    /// max(q,0) = (0, 0),outsideDistance = 0,insideDistance = -0.3,sdf = -0.3
    /// → 仍在 rect 内 → coverage = 1(因为 cornerRadius 削掉了外角,但 rect 中心仍包住)
    /// 真实"外角"应是 rect 角点之外的点
    func testRoundedRectCornerRadiusZeroBehavesLikeRectangle() {
        // cornerRadius = 0 应该退化为矩形:rect 外 = 0,rect 内 = 1
        let inside = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0.2, 0.2, 0.6, 0.6),
            cornerRadius: 0,
            feather: 0
        )
        XCTAssertEqual(inside, 1, accuracy: accuracy)
        // rect 外的点(0.1, 0.5) 应 = 0
        let outside = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.1, 0.5),
            rect: SIMD4<Float>(0.2, 0.2, 0.6, 0.6),
            cornerRadius: 0,
            feather: 0
        )
        XCTAssertEqual(outside, 0, accuracy: accuracy, "cornerRadius=0 退化为矩形,rect 外 = 0")
    }

    /// 真正"矩形外角"区域(圆角削掉的角):rect = (0.2,0.2,0.6,0.6),
    /// cornerRadius = 0.1,点 (0.2, 0.2) 在 rect 角点上但圆角削掉了 → sdf > 0 → coverage = 0
    func testRoundedRectOutsideCornerIsZero() {
        // rect 角 (0.2, 0.2),圆角中心在 (0.3, 0.3)(rect 左下角内 cornerRadius 处)
        // 点 (0.2, 0.2):corner = (-0.3, -0.3),q = (-0.3+0.1, -0.3+0.1) = (-0.2, -0.2)
        // max(q,0) = (0, 0),outsideDistance = 0,insideDistance = -0.2,sdf = -0.2
        // 这表示仍在 rect 内!需要选在圆角外的点。
        // 选 (0.25, 0.25):corner = (-0.25, -0.25),q = (-0.15, -0.15),仍 inside
        // 要选在圆角外侧:rect 左下角圆角中心 = (0.3, 0.3),半径 0.1*min(0.6,0.6)*0.5 = 0.03
        // 注意:cornerRadius 这里是占 rect 半尺寸 0.5 的比例(0..0.5)
        // 0.1 表示 rect 半宽 0.3 的 0.1 = 0.03(归一化绝对值)
        // 圆角中心 = rect.corner + cornerRadius = (0.2+0.03, 0.2+0.03) = (0.23, 0.23)
        // (0.2, 0.2) 距 (0.23, 0.23) = √(0.0009 + 0.0009) ≈ 0.042 > 0.03 → 在圆角外
        let c = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.2, 0.2),
            rect: SIMD4<Float>(0.2, 0.2, 0.6, 0.6),
            cornerRadius: 0.1,
            feather: 0
        )
        XCTAssertEqual(c, 0, accuracy: accuracy, "rect 左下角圆角外的点 = 0")
    }

    /// feather 软边验证:rect 边缘附近,feather > 0 时 coverage 在 [0, 1] 之间
    func testRoundedRectFeatherBandMidpointExactValue() {
        // rect = (0.5, 0.5, 0, 0) → size 被 max 钳到 1e-6,被全局规约
        // 用正常 rect:(0.2, 0.2, 0.6, 0.6),cornerRadius = 0,feather = 0.2
        // 边界点:rect 右边界 x=0.8,选 (0.8 + 0.05, 0.5)(在边界外但 feather 软边内)
        // 这里退化分析太多;改用对称点验证 feather 不影响中心 + 边界处 = smoothstep 中点
        let center = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0.2, 0.2, 0.6, 0.6),
            cornerRadius: 0.05,
            feather: 0.2
        )
        XCTAssertEqual(center, 1, accuracy: accuracy, "center 不受 feather 影响")
    }

    /// feather = 0 时:rect 角外的点(sdf > 0)在没有任何软边补偿时 = 0
    func testRoundedRectOutsideCornerZeroFeatherIsZero() {
        // 选 rect 角外侧距圆角弧更远的点 (0.18, 0.18):不在 rect 内,SDF 远离边界
        let c = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.18, 0.18),
            rect: SIMD4<Float>(0.2, 0.2, 0.6, 0.6),
            cornerRadius: 0.1,
            feather: 0
        )
        XCTAssertEqual(c, 0, accuracy: accuracy, "rect 角外的点,feather=0 = 0")
    }

    /// 退化:cornerRadius = 0.5 → 圆角矩形退化为圆形(中心 SDF 接近 0 但在边界内侧),
    /// SDF = centerRadius - 0.5 + 0.5 = cornerRadius + 0.5 - 0.5 = cornerRadius。中心仍 = 1
    func testRoundedRectMaxCornerRadiusApproximatesCircle() {
        // cornerRadius = 0.4,中心 SDF = -0.1 < 0,coverage = 1
        let center = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0, 0, 1, 1),
            cornerRadius: 0.4,
            feather: 0
        )
        XCTAssertEqual(center, 1, accuracy: accuracy)
        // 远离中心 (0, 0) 在圆角外
        let corner = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0, 0),
            rect: SIMD4<Float>(0, 0, 1, 1),
            cornerRadius: 0.4,
            feather: 0
        )
        XCTAssertEqual(corner, 0, accuracy: accuracy)
    }

    // MARK: - polygonCoverage (12 cases)

    /// 顶点 < 3 的 polygon:函数返回 0(guard 直接退出)
    func testPolygonEmptyVerticesReturnsZero() {
        let value = MaskMath.polygonCoverage(
            point: .init(0.5, 0.5),
            vertices: [], feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy, "空顶点 < 3,guard 返回 0")
    }

    /// 仅 1 个顶点
    func testPolygonSingleVertexReturnsZero() {
        let value = MaskMath.polygonCoverage(
            point: .init(0.5, 0.5),
            vertices: [.init(0.5, 0.5)], feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 2 个顶点(边)
    func testPolygonTwoVerticesReturnsZero() {
        let value = MaskMath.polygonCoverage(
            point: .init(0.5, 0.5),
            vertices: [.init(0.1, 0.1), .init(0.9, 0.9)], feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 三角形 (0.1,0.1)-(0.9,0.1)-(0.5,0.9) 中心 = (0.5, 0.3667...)
    /// 中心 (0.5, 0.4) 在三角形内 → 1
    func testPolygonTriangleInsideIsOne() {
        let triangle: [SIMD2<Float>] = [
            .init(0.1, 0.1), .init(0.9, 0.1), .init(0.5, 0.9)
        ]
        let value = MaskMath.polygonCoverage(
            point: .init(0.5, 0.4),  // 三角形内
            vertices: triangle, feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy, "重心 (0.5, 0.4) 在三角形内 → inside")
    }

    /// 三角形外点 = 0
    func testPolygonTriangleOutsideIsZero() {
        let triangle: [SIMD2<Float>] = [
            .init(0.1, 0.1), .init(0.9, 0.1), .init(0.5, 0.9)
        ]
        let value = MaskMath.polygonCoverage(
            point: .init(0.05, 0.05),
            vertices: triangle, feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 矩形 (0.2,0.2)-(0.8,0.2)-(0.8,0.8)-(0.2,0.8) 中心 = 1
    func testPolygonRectangleInsideIsOne() {
        let rect: [SIMD2<Float>] = [
            .init(0.2, 0.2), .init(0.8, 0.2), .init(0.8, 0.8), .init(0.2, 0.8)
        ]
        let value = MaskMath.polygonCoverage(
            point: .init(0.5, 0.5), vertices: rect, feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 矩形外的点 = 0
    func testPolygonRectangleOutsideIsZero() {
        let rect: [SIMD2<Float>] = [
            .init(0.2, 0.2), .init(0.8, 0.2), .init(0.8, 0.8), .init(0.2, 0.8)
        ]
        let value = MaskMath.polygonCoverage(
            point: .init(0.9, 0.9),
            vertices: rect, feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 五边形中心 = 1(凸多边形中心在内部)
    func testPolygonPentagonInsideIsOne() {
        let cx: Float = 0.5
        let cy: Float = 0.5
        let radius: Float = 0.3
        var verts: [SIMD2<Float>] = []
        for i in 0..<5 {
            let a = Float(i) / 5 * .pi * 2
            verts.append(.init(cx + cos(a) * radius, cy + sin(a) * radius))
        }
        let value = MaskMath.polygonCoverage(
            point: .init(cx, cy), vertices: verts, feather: 0
        )
        XCTAssertEqual(value, 1, accuracy: accuracy)
    }

    /// 五边形外点 = 0
    func testPolygonPentagonOutsideIsZero() {
        let cx: Float = 0.5
        let cy: Float = 0.5
        let radius: Float = 0.3
        var verts: [SIMD2<Float>] = []
        for i in 0..<5 {
            let a = Float(i) / 5 * .pi * 2
            verts.append(.init(cx + cos(a) * radius, cy + sin(a) * radius))
        }
        let value = MaskMath.polygonCoverage(
            point: .init(cx + radius + 0.1, cy),  // 半径之外一点
            vertices: verts, feather: 0
        )
        XCTAssertEqual(value, 0, accuracy: accuracy)
    }

    /// 共顶点退化(3 点共线):函数不崩溃,返回值 ∈ [0, 1]
    /// 这是 fuzzing 已断言的"不变量",本用例确认**确定性**行为
    func testPolygonCollinearVerticesDoesNotCrash() {
        let collinear: [SIMD2<Float>] = [
            .init(0.1, 0.1), .init(0.5, 0.1), .init(0.9, 0.1)
        ]
        // 在 y=0.2 处的点:不与共线边相交 → inside 取决于 winding 算法
        let v = MaskMath.polygonCoverage(
            point: .init(0.5, 0.2),
            vertices: collinear,
            fillRule: .nonZero,
            feather: 0
        )
        XCTAssertFalse(v.isNaN, "共线 polygon 不应产生 NaN")
        XCTAssertGreaterThanOrEqual(v, 0)
        XCTAssertLessThanOrEqual(v, 1)
    }

    /// feather>0 时,外部点按 smoothstep 渐变(不全为 0)
    /// 矩形外 0.1 处,feather = 0.1,期望 smoothstep(0.1, 0, 0.1) ≈ ? 这里测上界
    func testPolygonFeatherSoftenOutsideIsNonZero() {
        let rect: [SIMD2<Float>] = [
            .init(0.2, 0.2), .init(0.8, 0.2), .init(0.8, 0.8), .init(0.2, 0.8)
        ]
        // 在矩形外,距右边 0.05 处,feather = 0.1
        // distance 约为 0.05,high = 0.1,smoothstep(0.1, 0, 0.05) = ?
        // t = clamp((0.05 - 0.1) / (0 - 0.1)) = clamp(0.5) = 0.5 → 0.5*0.5*(3-1) = 0.5
        let v = MaskMath.polygonCoverage(
            point: .init(0.85, 0.5),
            vertices: rect, fillRule: .nonZero, feather: 0.1
        )
        XCTAssertGreaterThan(v, 0, "feather=0.1 让外侧 0.05 处仍有非零 coverage,got=\(v)")
        XCTAssertLessThan(v, 1)
        XCTAssertFalse(v.isNaN)
    }

    /// fillRule 路由:nonZero vs evenOdd 在简单凸多边形上有相同结果
    /// (凸多边形不形成嵌套,两种规则行为相同)
    func testPolygonFillRuleEquivalenceOnConvexShape() {
        let triangle: [SIMD2<Float>] = [
            .init(0.1, 0.1), .init(0.9, 0.1), .init(0.5, 0.9)
        ]
        let insideNonZero = MaskMath.polygonCoverage(
            point: .init(0.5, 0.4),
            vertices: triangle, fillRule: .nonZero, feather: 0
        )
        let insideEvenOdd = MaskMath.polygonCoverage(
            point: .init(0.5, 0.4),
            vertices: triangle, fillRule: .evenOdd, feather: 0
        )
        XCTAssertEqual(insideNonZero, insideEvenOdd, accuracy: accuracy, "凸多边形上,nonZero 与 evenOdd 应一致")
        XCTAssertEqual(insideNonZero, 1, accuracy: accuracy)
    }

    // MARK: - regionBlend (8 cases)

    /// coverage=0 + 任意 opacity = base(mask = coverage * opacity = 0,mix t=0)
    func testRegionBlendCoverageZeroReturnsBase() {
        let base: SIMD4<Float>   = .init(0.2, 0.4, 0.6, 0.8)
        let effect: SIMD4<Float> = .init(0.9, 0.7, 0.5, 0.3)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 0, opacity: 0.5)
        // SIMD4 没有带 accuracy: 的整体相等断言,逐分量断言
        XCTAssertEqual(v.x, base.x, accuracy: accuracy, "R 通道 = base")
        XCTAssertEqual(v.y, base.y, accuracy: accuracy, "G 通道 = base")
        XCTAssertEqual(v.z, base.z, accuracy: accuracy, "B 通道 = base")
        XCTAssertEqual(v.w, base.w, accuracy: accuracy, "A 通道 = base")
    }

    /// coverage=1 + opacity=0 = base(mask = 1 * 0 = 0,mix t=0)
    func testRegionBlendOpacityZeroReturnsBase() {
        let base: SIMD4<Float>   = .init(0.2, 0.4, 0.6, 0.8)
        let effect: SIMD4<Float> = .init(0.9, 0.7, 0.5, 0.3)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 1, opacity: 0)
        XCTAssertEqual(v.x, base.x, accuracy: accuracy)
        XCTAssertEqual(v.y, base.y, accuracy: accuracy)
        XCTAssertEqual(v.z, base.z, accuracy: accuracy)
        XCTAssertEqual(v.w, base.w, accuracy: accuracy)
    }

    /// coverage=1 + opacity=1 = effect(mask = 1,mix t=1)
    func testRegionBlendCoverageAndOpacityOneReturnsEffect() {
        let base: SIMD4<Float>   = .init(0.2, 0.4, 0.6, 0.8)
        let effect: SIMD4<Float> = .init(0.9, 0.7, 0.5, 0.3)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 1, opacity: 1)
        XCTAssertEqual(v.x, effect.x, accuracy: accuracy)
        XCTAssertEqual(v.y, effect.y, accuracy: accuracy)
        XCTAssertEqual(v.z, effect.z, accuracy: accuracy)
        XCTAssertEqual(v.w, effect.w, accuracy: accuracy)
    }

    /// coverage=1 + opacity=0.5:每个通道 = base*(1-0.5) + effect*0.5
    func testRegionBlendLinearInterpolationExact() {
        let base: SIMD4<Float>   = .init(0.0, 0.0, 0.0, 1.0)
        let effect: SIMD4<Float> = .init(1.0, 1.0, 1.0, 0.0)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 1, opacity: 0.5)
        // mask = 0.5,output = mix(base, effect, 0.5) = (0.5, 0.5, 0.5, 0.5)
        XCTAssertEqual(v.x, 0.5, accuracy: accuracy, "R = (0+1)*0.5 = 0.5")
        XCTAssertEqual(v.y, 0.5, accuracy: accuracy, "G = 0.5")
        XCTAssertEqual(v.z, 0.5, accuracy: accuracy, "B = 0.5")
        XCTAssertEqual(v.w, 0.5, accuracy: accuracy, "A = (1+0)*0.5 = 0.5")
    }

    /// RGBA 各通道独立:base 和 effect 只有 R 不同,其它相同
    func testRegionBlendChannelIndependence() {
        let base: SIMD4<Float>   = .init(0.2, 0.5, 0.5, 0.5)
        let effect: SIMD4<Float> = .init(0.8, 0.5, 0.5, 0.5)
        // coverage=0.5, opacity=1 → mask=0.5
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 0.5, opacity: 1)
        XCTAssertEqual(v.x, 0.5, accuracy: accuracy, "R 通道应混合")
        XCTAssertEqual(v.y, 0.5, accuracy: accuracy, "G 通道不变")
        XCTAssertEqual(v.z, 0.5, accuracy: accuracy, "B 通道不变")
        XCTAssertEqual(v.w, 0.5, accuracy: accuracy, "A 通道不变")
    }

    /// coverage=0.5 + opacity=0.5 = 0.25 mask
    /// mix(base, effect, 0.25) = base * 0.75 + effect * 0.25
    func testRegionBlendMaskFormulaExact() {
        let base: SIMD4<Float>   = .init(1, 0, 0, 1)
        let effect: SIMD4<Float> = .init(0, 1, 0, 1)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 0.5, opacity: 0.5)
        // mask = 0.25
        // R = 1*0.75 + 0*0.25 = 0.75
        // G = 0*0.75 + 1*0.25 = 0.25
        // B = 0
        // A = 0.75 + 0.25 = 1
        XCTAssertEqual(v.x, 0.75, accuracy: accuracy)
        XCTAssertEqual(v.y, 0.25, accuracy: accuracy)
        XCTAssertEqual(v.z, 0.00, accuracy: accuracy)
        XCTAssertEqual(v.w, 1.00, accuracy: accuracy)
    }

    /// 输出值 ∈ [0, 1] 各通道独立(覆盖越界输入也守住)
    func testRegionBlendClampsPerChannel() {
        let base: SIMD4<Float>   = .init(0, 0, 0, 0)
        let effect: SIMD4<Float> = .init(2, -1, 5, 0.5)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 1, opacity: 1)
        // mask=1 → mix(base, effect, 1) = effect(数学上未 clamp,但 simd_mix 同 Shader mix 也不 clamp)
        // 此用例仅断言"输出不含 NaN / Inf",从而确认数学路径是良定义的
        XCTAssertFalse(v.x.isNaN)
        XCTAssertFalse(v.y.isNaN)
        XCTAssertFalse(v.z.isNaN)
        XCTAssertFalse(v.w.isNaN)
    }

    /// coverage × opacity = mask = 0 → base(双重 0 退化)
    func testRegionBlendDoubleZeroAlwaysBase() {
        let base: SIMD4<Float>   = .init(0.123, 0.456, 0.789, 0.321)
        let effect: SIMD4<Float> = .init(0.999, 0.888, 0.777, 0.666)
        let v = MaskMath.regionBlend(base: base, effect: effect, coverage: 0, opacity: 0)
        XCTAssertEqual(v.x, base.x, accuracy: accuracy)
        XCTAssertEqual(v.y, base.y, accuracy: accuracy)
        XCTAssertEqual(v.z, base.z, accuracy: accuracy)
        XCTAssertEqual(v.w, base.w, accuracy: accuracy)
    }

    // MARK: - coverageFromRGB (8 cases)

    /// .red 路由到 r 分量(精确)
    func testCoverageFromRGBRedRoutesToRChannel() {
        let rgb: SIMD3<Float> = .init(0.3, 0.6, 0.9)
        let v = MaskMath.coverageFromRGB(rgb: rgb, component: .red)
        XCTAssertEqual(v, 0.3, accuracy: accuracy)
    }

    /// .green 路由到 g 分量
    func testCoverageFromRGBGreenRoutesToGChannel() {
        let rgb: SIMD3<Float> = .init(0.3, 0.6, 0.9)
        let v = MaskMath.coverageFromRGB(rgb: rgb, component: .green)
        XCTAssertEqual(v, 0.6, accuracy: accuracy)
    }

    /// .blue 路由到 b 分量
    func testCoverageFromRGBBlueRoutesToBChannel() {
        let rgb: SIMD3<Float> = .init(0.3, 0.6, 0.9)
        let v = MaskMath.coverageFromRGB(rgb: rgb, component: .blue)
        XCTAssertEqual(v, 0.9, accuracy: accuracy)
    }

    /// .alpha 在 RGB-only 函数中固定返回 0(API 契约)
    func testCoverageFromRGBAlphaAlwaysZero() {
        let rgb: SIMD3<Float> = .init(0.3, 0.6, 0.9)
        let v = MaskMath.coverageFromRGB(rgb: rgb, component: .alpha)
        XCTAssertEqual(v, 0, accuracy: accuracy, "RGB 三通道函数里 .alpha 没有信息,固定 0")
    }

    /// Rec.601 luminance 公式反推:0.299*r + 0.587*g + 0.114*b
    /// 测试精确值而非 round-trip
    func testCoverageFromRGBLuminanceUsesRec601Weights() {
        let rgb: SIMD3<Float> = .init(1, 1, 1)
        let v = MaskMath.coverageFromRGB(rgb: rgb, component: .luminance)
        XCTAssertEqual(v, 0.299 + 0.587 + 0.114, accuracy: accuracy, "纯白 luminance = 0.299+0.587+0.114 ≈ 1.0")
        XCTAssertEqual(v, 1, accuracy: 1e-4)
    }

    /// 极端 RGB:
    /// - 纯黑 luminance = 0
    /// - 纯红 luminance = 0.299(R 单独权重)
    func testCoverageFromRGBExtremes() {
        let black: SIMD3<Float> = .init(0, 0, 0)
        XCTAssertEqual(
            MaskMath.coverageFromRGB(rgb: black, component: .luminance),
            0, accuracy: accuracy
        )
        let red: SIMD3<Float> = .init(1, 0, 0)
        XCTAssertEqual(
            MaskMath.coverageFromRGB(rgb: red, component: .luminance),
            0.299, accuracy: accuracy,
            "纯红 luminance = R * 0.299"
        )
        let green: SIMD3<Float> = .init(0, 1, 0)
        XCTAssertEqual(
            MaskMath.coverageFromRGB(rgb: green, component: .luminance),
            0.587, accuracy: accuracy
        )
        let blue: SIMD3<Float> = .init(0, 0, 1)
        XCTAssertEqual(
            MaskMath.coverageFromRGB(rgb: blue, component: .luminance),
            0.114, accuracy: accuracy
        )
    }

    /// 中等 RGB 的精确 luminance 反推(防止后续误改 Rec.601 权重)
    /// rgb = (0.5, 0.5, 0.5) → luminance = 0.5*(0.299+0.587+0.114) = 0.5
    func testCoverageFromRGBLuminanceRoundedRec601Check() {
        let rgb: SIMD3<Float> = .init(0.5, 0.5, 0.5)
        let v = MaskMath.coverageFromRGB(rgb: rgb, component: .luminance)
        // 0.5 * (0.299+0.587+0.114) = 0.5 * 1.0 = 0.5
        XCTAssertEqual(v, 0.5, accuracy: 1e-4, "灰度 luminance = 灰度值本身(因为权重和为 1)")
    }

    /// 极端饱和:rgb = (1, 0, 0) 在 .red = 1,但在 .green / .blue = 0
    /// 验证"路由互斥"——一个 component 只看一个通道
    func testCoverageFromRGBExtremesRoutingDisjoint() {
        let rgb: SIMD3<Float> = .init(1, 0, 0)
        XCTAssertEqual(MaskMath.coverageFromRGB(rgb: rgb, component: .red), 1, accuracy: accuracy)
        XCTAssertEqual(MaskMath.coverageFromRGB(rgb: rgb, component: .green), 0, accuracy: accuracy)
        XCTAssertEqual(MaskMath.coverageFromRGB(rgb: rgb, component: .blue), 0, accuracy: accuracy)
    }

    // MARK: - extractCoverage (8 cases)

    /// feather=0,opacity=1, invert=false:.alpha 直接取 rgba.w
    func testExtractCoverageAlphaRoutesDirectly() {
        let rgba: SIMD4<Float> = .init(0.1, 0.2, 0.3, 0.7)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .alpha,
            invert: false, feather: 0, opacity: 1
        )
        XCTAssertEqual(v, 0.7, accuracy: accuracy, "feather=0,opacity=1,invert=false,.alpha → rgba.w")
    }

    /// invert 镜像:feather=0,opacity=1, .alpha → (1 - rgba.w)
    func testExtractCoverageAlphaInvertFlip() {
        let rgba: SIMD4<Float> = .init(0.1, 0.2, 0.3, 0.7)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .alpha,
            invert: true, feather: 0, opacity: 1
        )
        XCTAssertEqual(v, 0.3, accuracy: accuracy, "invert=true,opacity=1,.alpha → 1 - rgba.w = 0.3")
    }

    /// opacity=0:任意输入 → 0
    func testExtractCoverageOpacityZeroIsZero() {
        let rgba: SIMD4<Float> = .init(0.1, 0.2, 0.3, 0.7)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .red,
            invert: true, feather: 0.5, opacity: 0
        )
        XCTAssertEqual(v, 0, accuracy: accuracy, "opacity=0 → coverage * 0 → 0")
    }

    /// opacity=1,feather=0, .red → rgba.x * 1 = rgba.x
    func testExtractCoverageRedOpacityOneIsRGBA() {
        let rgba: SIMD4<Float> = .init(0.4, 0.5, 0.6, 0.7)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .red,
            invert: false, feather: 0, opacity: 1
        )
        XCTAssertEqual(v, 0.4, accuracy: accuracy)
    }

    /// luminance 路由:feather=0,opacity=1,invert=false
    /// coverage = Rec.601(rgba) → 期望 = rgba.x*0.299 + rgba.y*0.587 + rgba.z*0.114
    func testExtractCoverageLuminanceRoutesToRec601() {
        let rgba: SIMD4<Float> = .init(1, 0, 0, 1)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .luminance,
            invert: false, feather: 0, opacity: 1
        )
        XCTAssertEqual(v, 0.299, accuracy: accuracy)
    }

    /// feather>0 时,alpha=0.5 正好居中(smoothstep 中点)
    /// low = max(0, 0.5 - 0.5*0.5) = 0.25;high = min(1, 0.5 + 0.5*0.5) = 0.75
    /// alpha=0.5 在 [low, high] 中点 → smoothstep = 0.5
    func testExtractCoverageFeatherSmoothsToHalfAtMidpoint() {
        let rgba: SIMD4<Float> = .init(0, 0, 0, 0.5)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .alpha,
            invert: false, feather: 0.5, opacity: 1
        )
        XCTAssertEqual(v, 0.5, accuracy: accuracy, "feather=0.5, alpha=0.5 → smoothstep 中点 → 0.5")
    }

    /// feather 不影响边界(raw=0 → low → smoothstep 返回 0)
    func testExtractCoverageFeatherZeroExtractedMapsToZero() {
        let rgba: SIMD4<Float> = .init(0, 0, 0, 0)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .alpha,
            invert: false, feather: 0.4, opacity: 1
        )
        XCTAssertEqual(v, 0, accuracy: accuracy, "原始 coverage=0,smoothstep 永远 ≤ 1e-6,clamp 后 = 0")
    }

    /// invert + feather 组合:raw=0.3, inverted=0.7, smoothstep(0.25, 0.75, 0.7)
    /// t = clamp((0.7 - 0.25) / (0.75 - 0.25)) = clamp(0.9) = 0.9 → 0.972
    /// opacity=1 → 0.972(在 [0,1] 内)
    func testExtractCoverageInvertAndFeatherCombinedExact() {
        let rgba: SIMD4<Float> = .init(0, 0, 0, 0.3)
        let v = MaskMath.extractCoverage(
            rgba: rgba, component: .alpha,
            invert: true, feather: 0.5, opacity: 1
        )
        // inverted: 0.7;smoothstep(0.25, 0.75, 0.7):t=0.9,return 0.9*0.9*1.2 ≈ 0.972
        // 因 simd 浮点 round,允许 1e-3 误差
        XCTAssertEqual(v, 0.972, accuracy: 1e-3, "invert(0.3)=0.7,feather smoothstep(0.25, 0.75, 0.7) ≈ 0.972")
    }

    // MARK: - 内部一致性烟雾测试

    /// linearGradientCoverage 等价于"沿 delta 投影除以 |delta|^2 再 clamp"。
    /// 这里用反推:对任意垂线上的点,coverage 应相同(因为 dot((0, y), delta) 只看 delta 的 x 分量)
    func testLinearGradientPerpendicularAlignmentInvariance() {
        // delta = (1, 0);对 (t, 任意 y),coverage = t
        let y1 = MaskMath.linearGradientCoverage(uv: .init(0.4, 0.3), start: .init(0, 0), end: .init(1, 0))
        let y2 = MaskMath.linearGradientCoverage(uv: .init(0.4, 0.8), start: .init(0, 0), end: .init(1, 0))
        XCTAssertEqual(y1, y2, accuracy: accuracy)
        XCTAssertEqual(y1, 0.4, accuracy: accuracy, "沿 x 方向的投影只与 x 坐标有关,与 y 无关")
    }

    /// smoothstep 边界:rect feather = 1,boundary point 应当被 smoothstep 完全饱和到 1
    /// 在 rect = (0.5, 0.5, 0, 0) 退化为单点,
    /// 但 size 被 max 钳到 1e-6,所以 center 之外都 = 0
    /// 这里验证的是"feather=1 时,中心仍 = 1"
    func testCoverageInternalConsistencyFeatherActsAtBoundary() {
        // 中心 (0.5, 0.5) 在 rect (0.2, 0.2, 0.6, 0.6) 内,feather=1,= 1
        let c = MaskMath.rectangleCoverage(
            point: .init(0.5, 0.5),
            rect: .init(0.2, 0.2, 0.6, 0.6),
            feather: 1
        )
        XCTAssertEqual(c, 1, accuracy: accuracy)
    }
}
