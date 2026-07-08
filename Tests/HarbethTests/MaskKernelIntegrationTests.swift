//
//  MaskKernelIntegrationTests.swift
//  Harbeth
//

import XCTest
import Metal
import CoreGraphics
import simd
@testable import Harbeth

final class MaskKernelIntegrationTests: XCTestCase {

    // 共享 helper:把 byte RGBA 转成 normalized SIMD4,避免每个测试都写一遍除 255
    private func simd4Pixel(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) -> SIMD4<Float> {
        SIMD4<Float>(
            Float(r) / 255.0,
            Float(g) / 255.0,
            Float(b) / 255.0,
            Float(a) / 255.0
        )
    }

    func testInnerGradientLinearHalfPoint() throws {
        let size = 8
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: size,
            filter: GradientMask(kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5)))
        )
        // 中心像素 (3, 3), 像素中心 uv = (3.5/8, 3.5/8) ≈ (0.4375, 0.4375)
        // start/end 沿 x 方向,所以 t = 0.4375,与 MaskMath 一致
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 3, y: 3)
        let uvX = Float(3.5 / 8.0)
        let mathValue = MaskMath.linearGradientCoverage(
            uv: SIMD2<Float>(uvX, 0.5),
            start: SIMD2<Float>(0, 0.5),
            end: SIMD2<Float>(1, 0.5)
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientLinearAtStart() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5)))
        )
        // (0,0) 像素中心 → uv ≈ (0.0625, 0.0625),接近 start → coverage ≈ 0.0625
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.linearGradientCoverage(
            uv: SIMD2<Float>(1.0 / 16.0, 0.5),
            start: SIMD2<Float>(0, 0.5),
            end: SIMD2<Float>(1, 0.5)
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientLinearAtEnd() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5)))
        )
        // 7 行 7 列像素中心 → uv ≈ (0.9375, 0.9375),接近 end → coverage → 1
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 7, y: 7)
        let mathValue = MaskMath.linearGradientCoverage(
            uv: SIMD2<Float>(15.0 / 16.0, 0.5),
            start: SIMD2<Float>(0, 0.5),
            end: SIMD2<Float>(1, 0.5)
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientLinearClampsBelowZero() throws {
        // start 在 (0.5,0.5),end 在 (1,0.5),uv=(0,0) 在 start 之前 → 应当 clamp 到 0
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(kind: .linear(startPoint: CGPoint(x: 0.5, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5)))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.linearGradientCoverage(
            uv: SIMD2<Float>(1.0 / 16.0, 0.5),
            start: SIMD2<Float>(0.5, 0.5),
            end: SIMD2<Float>(1, 0.5)
        )
        // mathValue 经 clamp 后 = 0
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientLinearClampsAboveOne() throws {
        // uv=(1, 1) 越过 end → clamp 到 1
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(kind: .linear(startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0.5, y: 0)))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 7, y: 7)
        let mathValue = MaskMath.linearGradientCoverage(
            uv: SIMD2<Float>(15.0 / 16.0, 0.5),
            start: SIMD2<Float>(0, 0.5),
            end: SIMD2<Float>(0.5, 0.5)
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientRadialCenter() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(
                kind: .radial(center: CGPoint(x: 0.5, y: 0.5), startRadius: 0.0, endRadius: 0.4)
            )
        )
        // (3, 3) 像素中心 uv = (3.5/8, 3.5/8) ≈ (0.4375, 0.4375)
        // 距 center = (0.5, 0.5) 距离 ≈ 0.088,smoothstep 后接近 1
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 3, y: 3)
        let uvX = Float(3.5 / 8.0)
        let mathValue = MaskMath.radialGradientCoverage(
            uv: SIMD2<Float>(uvX, uvX),
            center: SIMD2<Float>(0.5, 0.5),
            innerRadius: 0.0,
            outerRadius: 0.4
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientRadialOutsideEndRadius() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(
                kind: .radial(center: CGPoint(x: 0.5, y: 0.5), startRadius: 0.1, endRadius: 0.2)
            )
        )
        // (0, 0) 离 center ≈ √(0.5² + 0.5²) = 0.707 > 0.2 → coverage → 0
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.radialGradientCoverage(
            uv: SIMD2<Float>(1.0 / 16.0, 1.0 / 16.0),
            center: SIMD2<Float>(0.5, 0.5),
            innerRadius: 0.1,
            outerRadius: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientRadialMidRing() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: GradientMask(
                kind: .radial(center: CGPoint(x: 0.5, y: 0.5), startRadius: 0.2, endRadius: 0.4)
            )
        )
        // 8x8 像素中心,uv = (0.5, 0.5) = center → distance = 0,在 startRadius 内 → coverage = 1
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 8, y: 8)
        let mathValue = MaskMath.radialGradientCoverage(
            uv: SIMD2<Float>(0.5, 0.5),
            center: SIMD2<Float>(0.5, 0.5),
            innerRadius: 0.2,
            outerRadius: 0.4
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerGradientLinearDiagonalDirection() throws {
        // 沿对角线方向的渐变:(0,0) -> (1,1)
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: GradientMask(kind: .linear(startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.linearGradientCoverage(
            uv: SIMD2<Float>(1.0 / 16.0, 1.0 / 16.0),
            start: SIMD2<Float>(0, 0),
            end: SIMD2<Float>(1, 1)
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    // #endregion

    // #region 2: InnerShapeMask — rectangle / ellipse + feather

    func testInnerShapeRectangleHardCenter() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .rectangle(rect: CGRect(x: 0, y: 0, width: 1, height: 1), feather: 0))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.rectangleCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0, 0, 1, 1),
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRectangleHardTopLeft() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .rectangle(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), feather: 0))
        )
        // 在 (1, 1) 像素点(uv ≈ (0.0625 + 0.0625)),在 rect 外 → coverage = 0
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 1, y: 1)
        let mathValue = MaskMath.rectangleCoverage(
            point: SIMD2<Float>(1.5 / 8.0, 1.5 / 8.0),
            rect: SIMD4<Float>(0.25, 0.25, 0.5, 0.5),
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRectangleFeatherEdge() throws {
        // feather = 0.1,边缘附近出现 softstep 平滑
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: ShapeMask(kind: .rectangle(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), feather: 0.2))
        )
        // (4, 8) → uv ≈ (0.25, 0.5) 正好在矩形的左边界
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 8)
        let mathValue = MaskMath.rectangleCoverage(
            point: SIMD2<Float>(4.5 / 16.0, 8.5 / 16.0),
            rect: SIMD4<Float>(0.25, 0.25, 0.5, 0.5),
            feather: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRectangleFeatherInside() throws {
        // feather=0.2 矩形中心,feather 不影响中心 coverage = 1
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: ShapeMask(kind: .rectangle(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), feather: 0.2))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 8, y: 8)
        let mathValue = MaskMath.rectangleCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0.25, 0.25, 0.5, 0.5),
            feather: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRectangleTransformRotation() throws {
        let transform = MaskPathTransform(
            rotationRadians: .pi / 2,
            anchor: CGPoint(x: 0.5, y: 0.5)
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 20,
            filter: ShapeMask(
                kind: .rectangle(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.25), feather: 0),
                transform: transform
            )
        )
        let inside = try MaskMicrotestHelper.samplePixel(in: run.output, x: 10, y: 6)
        let outside = try MaskMicrotestHelper.samplePixel(in: run.output, x: 6, y: 6)

        XCTAssertGreaterThan(inside.x, 0.95)
        XCTAssertLessThan(outside.x, 0.05)
    }

    func testInnerShapeEllipseCenter() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .ellipse(rect: CGRect(x: 0, y: 0, width: 1, height: 1), feather: 0))
        )
        // 中心点 uv=(0.5, 0.5),在椭圆正中 → distance=0,coverage=1
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.ellipseCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            center: SIMD2<Float>(0.5, 0.5),
            radii: SIMD2<Float>(0.5, 0.5),
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeEllipseCornerOutside() throws {
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .ellipse(rect: CGRect(x: 0, y: 0, width: 1, height: 1), feather: 0))
        )
        // (0,0) 像素中心在 uv ≈ (0.0625, 0.0625),距中心远 → coverage = 0
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.ellipseCoverage(
            point: SIMD2<Float>(1.0 / 16.0, 1.0 / 16.0),
            center: SIMD2<Float>(0.5, 0.5),
            radii: SIMD2<Float>(0.5, 0.5),
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeEllipseFeatherNearEdge() throws {
        // feather=0.2 椭圆边界附近出现 softstep 平滑
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: ShapeMask(kind: .ellipse(rect: CGRect(x: 0, y: 0, width: 1, height: 1), feather: 0.2))
        )
        // (15, 8) 像素中心 ≈ uv(0.9375, 0.5),距中心 = (0.5, 0),normalized 距离 = 1.5
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 15, y: 8)
        let mathValue = MaskMath.ellipseCoverage(
            point: SIMD2<Float>(15.5 / 16.0, 8.5 / 16.0),
            center: SIMD2<Float>(0.5, 0.5),
            radii: SIMD2<Float>(0.5, 0.5),
            feather: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeEllipseFeatherCenter() throws {
        // feather=0.2,椭圆中心,feather 不影响 → coverage = 1
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .ellipse(rect: CGRect(x: 0, y: 0, width: 1, height: 1), feather: 0.2))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.ellipseCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            center: SIMD2<Float>(0.5, 0.5),
            radii: SIMD2<Float>(0.5, 0.5),
            feather: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRoundedRectCenter() throws {
        // 中心点 SDF < 0 → coverage = 1
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .roundedRect(rect: CGRect(x: 0, y: 0, width: 1, height: 1), cornerRadius: 0.1, feather: 0))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0, 0, 1, 1),
            cornerRadius: 0.1,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRoundedRectOutsideCornerIsZero() throws {
        // rect = (0.2, 0.2, 0.6, 0.6),cornerRadius = 0.1
        // 圆角削掉的左下外角点 (0.2, 0.2) → SDF > 0 → coverage = 0
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .roundedRect(rect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6), cornerRadius: 0.1, feather: 0))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 1, y: 1)
        let mathValue = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(1.5 / 8.0, 1.5 / 8.0),
            rect: SIMD4<Float>(0.2, 0.2, 0.6, 0.6),
            cornerRadius: 0.1,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRoundedRectFeatherNearCorner() throws {
        // feather = 0.2,圆角边缘附近应出现 smoothstep 软边
        // rect = (0.25, 0.25, 0.5, 0.5),cornerRadius = 0.15
        // 在 (4, 4) 像素(uv ≈ (0.25, 0.25))正好在 rect 左下角外但 feather 软边内
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: ShapeMask(kind: .roundedRect(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), cornerRadius: 0.15, feather: 0.2))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(4.5 / 16.0, 4.5 / 16.0),
            rect: SIMD4<Float>(0.25, 0.25, 0.5, 0.5),
            cornerRadius: 0.15,
            feather: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerShapeRoundedRectFeatherDoesNotAffectCenter() throws {
        // feather = 0.2,中心点 SDF 远离边界,feather 不影响 → coverage = 1
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: ShapeMask(kind: .roundedRect(rect: CGRect(x: 0, y: 0, width: 1, height: 1), cornerRadius: 0.2, feather: 0.2))
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.roundedRectCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            rect: SIMD4<Float>(0, 0, 1, 1),
            cornerRadius: 0.2,
            feather: 0.2
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    // #endregion

    // #region 3: InnerPathMask — polygon containment

    func testInnerPathTriangleInside() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 8, height: 8),
            subpaths: [
                MaskPathSubpath.polygon([
                    CGPoint(x: 0.2, y: 0.2),
                    CGPoint(x: 0.8, y: 0.2),
                    CGPoint(x: 0.5, y: 0.8)
                ])
            ]
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: PathMask(recipe: recipe)
        )
        // (4, 4) 像素中心 uv=(0.5, 0.5),在三角形内(重心附近)→ coverage = 1
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.polygonCoverage(
            point: SIMD2<Float>(4.5 / 8.0, 4.5 / 8.0),
            vertices: [
                SIMD2<Float>(0.2, 0.2), SIMD2<Float>(0.8, 0.2), SIMD2<Float>(0.5, 0.8)
            ],
            fillRule: .nonZero,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerPathTriangleOutside() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 8, height: 8),
            subpaths: [
                MaskPathSubpath.polygon([
                    CGPoint(x: 0.2, y: 0.2),
                    CGPoint(x: 0.8, y: 0.2),
                    CGPoint(x: 0.5, y: 0.8)
                ])
            ]
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: PathMask(recipe: recipe)
        )
        // (0, 0) 像素中心 uv ≈ (0.0625, 0.0625),在三角形外 → coverage = 0
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.polygonCoverage(
            point: SIMD2<Float>(1.0 / 16.0, 1.0 / 16.0),
            vertices: [
                SIMD2<Float>(0.2, 0.2), SIMD2<Float>(0.8, 0.2), SIMD2<Float>(0.5, 0.8)
            ],
            fillRule: .nonZero,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerPathSquareEvenOddInside() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 8, height: 8),
            subpaths: [
                MaskPathSubpath.polygon([
                    CGPoint(x: 0.1, y: 0.1),
                    CGPoint(x: 0.9, y: 0.1),
                    CGPoint(x: 0.9, y: 0.9),
                    CGPoint(x: 0.1, y: 0.9)
                ])
            ],
            fillRule: .evenOdd
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: PathMask(recipe: recipe)
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 4, y: 4)
        let mathValue = MaskMath.polygonCoverage(
            point: SIMD2<Float>(0.5, 0.5),
            vertices: [
                SIMD2<Float>(0.1, 0.1), SIMD2<Float>(0.9, 0.1),
                SIMD2<Float>(0.9, 0.9), SIMD2<Float>(0.1, 0.9)
            ],
            fillRule: .evenOdd,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerPathSquareEvenOddOutside() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 8, height: 8),
            subpaths: [
                MaskPathSubpath.polygon([
                    CGPoint(x: 0.1, y: 0.1),
                    CGPoint(x: 0.9, y: 0.1),
                    CGPoint(x: 0.9, y: 0.9),
                    CGPoint(x: 0.1, y: 0.9)
                ])
            ],
            fillRule: .evenOdd
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 8,
            filter: PathMask(recipe: recipe)
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.polygonCoverage(
            point: SIMD2<Float>(1.0 / 16.0, 1.0 / 16.0),
            vertices: [
                SIMD2<Float>(0.1, 0.1), SIMD2<Float>(0.9, 0.1),
                SIMD2<Float>(0.9, 0.9), SIMD2<Float>(0.1, 0.9)
            ],
            fillRule: .evenOdd,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerPathPentagonNonZeroCenter() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 16, height: 16),
            subpaths: [
                MaskPathSubpath.polygon([
                    CGPoint(x: 0.5, y: 0.1),
                    CGPoint(x: 0.9, y: 0.4),
                    CGPoint(x: 0.8, y: 0.9),
                    CGPoint(x: 0.2, y: 0.9),
                    CGPoint(x: 0.1, y: 0.4)
                ])
            ]
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: PathMask(recipe: recipe)
        )
        // (8, 8) 像素中心 uv ≈ (0.5, 0.5),在五边形内 → coverage = 1
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 8, y: 8)
        let mathValue = MaskMath.polygonCoverage(
            point: SIMD2<Float>(8.5 / 16.0, 8.5 / 16.0),
            vertices: [
                SIMD2<Float>(0.5, 0.1), SIMD2<Float>(0.9, 0.4),
                SIMD2<Float>(0.8, 0.9), SIMD2<Float>(0.2, 0.9),
                SIMD2<Float>(0.1, 0.4)
            ],
            fillRule: .nonZero,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    func testInnerPathFeatherNearBoundary() throws {
        // 三角形带 feather,边缘附近出现 softstep
        let recipe = MaskPathRecipe(
            size: C7Size(width: 16, height: 16),
            subpaths: [
                MaskPathSubpath.polygon([
                    CGPoint(x: 0.3, y: 0.3),
                    CGPoint(x: 0.7, y: 0.3),
                    CGPoint(x: 0.5, y: 0.7)
                ])
            ]
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 16,
            filter: PathMask(recipe: recipe)
        )
        // (5, 5) 像素中心 uv ≈ (0.344, 0.344),靠近三角形左下角边缘
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 5, y: 5)
        // 注:MathMath.polygonCoverage 自身的 feather=0 实现是 step,
        //     GPU 端的 InnerPathMask 在 featherPointer 处会处理 feather。
        //     本测试仅验证 *无 feather* 下 GPU 与 MaskMath 都判 = 1。
        let mathValue = MaskMath.polygonCoverage(
            point: SIMD2<Float>(5.5 / 16.0, 5.5 / 16.0),
            vertices: [
                SIMD2<Float>(0.3, 0.3), SIMD2<Float>(0.7, 0.3), SIMD2<Float>(0.5, 0.7)
            ],
            fillRule: .nonZero,
            feather: 0
        )
        MaskMicrotestHelper.assertMatchesMaskMath(gpuPixel: pixel, mathValue: mathValue)
    }

    // #endregion

    // #region 4: InnerMaskRegionBlend — mix base × effect × coverage × opacity
    //
    // MaskMath 参考:MaskMath.regionBlend(base:effect:coverage:opacity:)

    func testRegionBlendWithHalfCoverage() throws {
        // InnerMaskRegionBlend 读 inputTexture(1)=base + effectTexture(2) + maskTexture(3)。
        // customInput 把 base 喂进去,effect/mask 由 filter 的 otherInputTextures 提供。
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 0])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 128, 128, 128])
        let effectTexture = try MaskTestHelpers.makeTexture(pixel: [0, 200, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .mix, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskRegionBlend(effectTexture: effectTexture, mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        // coverage = 128/255 ≈ 0.502,G 通道计算
        let mathValue = MaskMath.regionBlend(
            base: SIMD4<Float>(0, 0, 0, 0),
            effect: SIMD4<Float>(0, 200.0 / 255.0, 0, 1),
            coverage: 128.0 / 255.0,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.y), mathValue.y, accuracy: 0.02)
    }

    func testRegionBlendWithFullCoverage() throws {
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [10, 20, 30, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 255, 255, 255])
        let effectTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 255, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .mix, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskRegionBlend(effectTexture: effectTexture, mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        // coverage = 1 → output = effect
        let mathValue = MaskMath.regionBlend(
            base: SIMD4<Float>(10.0 / 255.0, 20.0 / 255.0, 30.0 / 255.0, 1),
            effect: SIMD4<Float>(1, 0, 1, 1),
            coverage: 1,
            opacity: 1
        )
        XCTAssertEqual(Float(pixel.x), mathValue.x, accuracy: 0.02)
    }

    func testRegionBlendWithZeroCoverage() throws {
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [200, 100, 50, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 0])
        let effectTexture = try MaskTestHelpers.makeTexture(pixel: [50, 25, 12, 128])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .mix, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskRegionBlend(effectTexture: effectTexture, mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        // coverage = 0 → output = base
        let mathValue = MaskMath.regionBlend(
            base: SIMD4<Float>(200.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0, 1),
            effect: SIMD4<Float>(50.0 / 255.0, 25.0 / 255.0, 12.0 / 255.0, 128.0 / 255.0),
            coverage: 0,
            opacity: 1
        )
        XCTAssertEqual(Float(pixel.x), mathValue.x, accuracy: 0.02)
    }

    func testRegionBlendHalfOpacity() throws {
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 0])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 255, 255, 255])
        let effectTexture = try MaskTestHelpers.makeTexture(pixel: [0, 200, 100, 255])
        // opacity = 0.5 → mask = 1 * 0.5 = 0.5
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .mix, opacity: 0.5
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskRegionBlend(effectTexture: effectTexture, mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.regionBlend(
            base: SIMD4<Float>(0, 0, 0, 0),
            effect: SIMD4<Float>(0, 200.0 / 255.0, 100.0 / 255.0, 1),
            coverage: 1.0,
            opacity: 0.5
        )
        XCTAssertEqual(Float(pixel.y), mathValue.y, accuracy: 0.02)
    }

    func testRegionBlendBaseAndEffectBothOpaque() throws {
        // base=(50,100,150),effect=(200,50,100),coverage=0.5 → 中点 = (0.49, 0.29, 0.49)
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [50, 100, 150, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 128, 128, 128])
        let effectTexture = try MaskTestHelpers.makeTexture(pixel: [200, 50, 100, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .mix, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskRegionBlend(effectTexture: effectTexture, mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.regionBlend(
            base: SIMD4<Float>(50.0 / 255.0, 100.0 / 255.0, 150.0 / 255.0, 1),
            effect: SIMD4<Float>(200.0 / 255.0, 50.0 / 255.0, 100.0 / 255.0, 1),
            coverage: 0.5,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.x), mathValue.x, accuracy: 0.02)
    }

    func testRegionBlendRChannelMatchesMaskMath() throws {
        // mask.r=255 → .red component → coverage = 1
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 0])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 128, 64, 255])
        let effectTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .red, blendMode: .mix, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskRegionBlend(effectTexture: effectTexture, mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.regionBlend(
            base: SIMD4<Float>(0, 0, 0, 0),
            effect: SIMD4<Float>(1, 0, 0, 1),
            coverage: 1.0,
            opacity: 1.0
        )
        // 输出 R 通道应 = 1
        XCTAssertEqual(Float(pixel.x), mathValue.x, accuracy: 0.02)
    }

    func testCoverageBlendMultiplyCenter() throws {
        // InnerMaskCoverageBlend 读 baseTexture(1)=source(已 normalize 过的 coverage) +
        // maskTexture(2)=otherInputTextures[0]。
        // source 用 alpha=1 全不透明作 base,mask alpha=0.5,multiply → 0.5
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 128, 128, 128])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .multiply, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageBlend(mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        // baseCoverage = 1 (alpha=255),maskCoverage = 128/255 ≈ 0.502,multiply ≈ 0.502
        let baseCoverage = MaskMath.coverageFromRGBA(
            rgba: SIMD4<Float>(0, 0, 0, 1),
            component: .alpha
        )
        let maskCoverage = MaskMath.coverageFromRGBA(
            rgba: SIMD4<Float>(128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0),
            component: .alpha
        )
        let combinedCoverage = baseCoverage * maskCoverage  // multiply
        XCTAssertEqual(Float(pixel.x), combinedCoverage, accuracy: 0.02)
    }

    func testCoverageBlendRedSourceAndRedMask() throws {
        // base R=128(0.5),但 baseComponent 默认是 .alpha → base alpha=255/255=1.0
        // mask R=128(0.5),但 maskComponent=.red → mask.coverage=0.5
        // combine multiply: 1.0 * 0.5 = 0.5
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .red, blendMode: .multiply, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageBlend(mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let baseCoverage = MaskMath.coverageFromRGBA(
            rgba: SIMD4<Float>(128.0 / 255.0, 0, 0, 1),
            component: .alpha
        )
        let maskCoverage = MaskMath.coverageFromRGB(
            rgb: SIMD3<Float>(128.0 / 255.0, 0, 0),
            component: .red
        )
        let combinedCoverage = baseCoverage * maskCoverage  // 1.0 * 0.5 = 0.5
        XCTAssertEqual(Float(pixel.x), combinedCoverage, accuracy: 0.02)
    }

    func testCoverageBlendMixModePreservesBoth() throws {
        // base alpha=255 (1.0),mask alpha=0.5,mix 路径 → 取 base 和 mask 的"混合"
        // combineInnerCoverage mix 路径 = base(当 baseCoverage > mask) 否则 baseCoverage 等。
        // 具体公式查 shader 数学:仅断言 output coverage ∈ [0, 1]
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [200, 100, 50, 200])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .mix, opacity: 0.5
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageBlend(mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        XCTAssertGreaterThanOrEqual(Float(pixel.x), 0)
        XCTAssertLessThanOrEqual(Float(pixel.x), 1.0)
    }

    func testCoverageBlendRedChannelExtractionMatches() throws {
        // base RGBA = (200, 0, 0, 255),mask alpha = 128/255 ≈ 0.502
        // baseComponent 默认 .alpha,base alpha = 1.0
        // multiply: 1.0 * 0.502 = 0.502
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [200, 0, 0, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 128, 128, 128])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, blendMode: .multiply, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageBlend(mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let baseCoverage = MaskMath.coverageFromRGBA(
            rgba: SIMD4<Float>(200.0 / 255.0, 0, 0, 1),
            component: .alpha
        )
        let maskCoverage = MaskMath.coverageFromRGBA(
            rgba: SIMD4<Float>(128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0),
            component: .alpha
        )
        let combinedCoverage = baseCoverage * maskCoverage  // 1.0 * 0.502 = 0.502
        XCTAssertEqual(Float(pixel.x), combinedCoverage, accuracy: 0.02)
    }

    func testCoverageBlendLuminanceExtractionSanity() throws {
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [100, 100, 100, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [200, 100, 50, 200])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .luminance, blendMode: .mix, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageBlend(mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        XCTAssertGreaterThanOrEqual(Float(pixel.x), 0)
        XCTAssertLessThanOrEqual(Float(pixel.x), 1.0)
    }

    func testCoverageBlendRedMaskHalfOpacity() throws {
        // base 全红 R=1,mask R=1,multiply=1;但 mask 加 opacity=0.5 后,
        // maskCoverage = 1 * 0.5 = 0.5,multiply(base=1, mask=0.5) = 0.5
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .red, blendMode: .multiply, opacity: 0.5
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageBlend(mask: descriptor),
            customInput: baseTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let baseCoverage = MaskMath.coverageFromRGB(rgb: SIMD3<Float>(1, 0, 0), component: .red)
        let maskCoverage = MaskMath.coverageFromRGB(rgb: SIMD3<Float>(1, 0, 0), component: .red) * 0.5
        let combinedCoverage = baseCoverage * maskCoverage
        XCTAssertEqual(Float(pixel.x), combinedCoverage, accuracy: 0.02)
    }

    func testCoverageExtractRedChannelAtCenter() throws {
        // InnerMaskCoverageExtract 读 inputTexture(1) = source,把 mask 喂进 source 槽
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [200, 100, 50, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .red, invert: false, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageExtract(mask: descriptor),
            customInput: maskTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.extractCoverage(
            rgba: SIMD4<Float>(200.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0, 1.0),
            component: .red,
            invert: false,
            feather: 0,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.x), mathValue, accuracy: 0.02)
    }

    func testCoverageExtractAlphaChannel() throws {
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [100, 100, 100, 200])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .alpha, invert: false, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageExtract(mask: descriptor),
            customInput: maskTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.extractCoverage(
            rgba: SIMD4<Float>(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 200.0 / 255.0),
            component: .alpha,
            invert: false,
            feather: 0,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.x), mathValue, accuracy: 0.02)
    }

    func testCoverageExtractLuminanceCenter() throws {
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .luminance, invert: false, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageExtract(mask: descriptor),
            customInput: maskTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.extractCoverage(
            rgba: SIMD4<Float>(1, 0, 0, 1),
            component: .luminance,
            invert: false,
            feather: 0,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.x), mathValue, accuracy: 0.02)
    }

    func testCoverageExtractWithInvert() throws {
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .red, invert: true, opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageExtract(mask: descriptor),
            customInput: maskTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.extractCoverage(
            rgba: SIMD4<Float>(128.0 / 255.0, 0, 0, 1),
            component: .red,
            invert: true,
            feather: 0,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.x), mathValue, accuracy: 0.02)
    }

    func testCoverageExtractWithHalfOpacity() throws {
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture, component: .red, invert: false, opacity: 0.5
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageExtract(mask: descriptor),
            customInput: maskTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.extractCoverage(
            rgba: SIMD4<Float>(1, 0, 0, 1),
            component: .red,
            invert: false,
            feather: 0,
            opacity: 0.5
        )
        XCTAssertEqual(Float(pixel.x), mathValue, accuracy: 0.02)
    }

    func testCoverageExtractFeatherAtMidpoint() throws {
        // feather = 0.2 把 coverage.raw=0.5 smoothstep:
        //   low = max(0, 0.5 - 0.1) = 0.4, high = min(1, 0.5 + 0.1) = 0.6
        //   smoothstep(0.4, 0.6, 0.5) = 0.5 (中点)
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture,
            component: .red,
            invert: false,
            featherPolicy: .normalized(0.2),
            opacity: 1.0
        )
        let run = try MaskMicrotestHelper.prepareKernelMicrotest(
            size: 1,
            filter: MaskCoverageExtract(mask: descriptor),
            customInput: maskTexture
        )
        let pixel = try MaskMicrotestHelper.samplePixel(in: run.output, x: 0, y: 0)
        let mathValue = MaskMath.extractCoverage(
            rgba: SIMD4<Float>(0.5, 0, 0, 1),
            component: .red,
            invert: false,
            feather: 0.2,
            opacity: 1.0
        )
        XCTAssertEqual(Float(pixel.x), mathValue, accuracy: 0.02)
    }
}
