//
//  MaskMath.swift
//  Harbeth
//
//  Created by Condy on 2026/7/1.
//

import Foundation
import simd

/// GPU mask kernel 的纯 Swift 数学镜像。
///
/// 每个函数对应 `InnerShaders.metal` 中一个 kernel 内部核心公式，
/// 不依赖 Metal / MTLDevice / MTLTexture，纯 CPU 可执行，可在 <0.1 秒内
/// 跑完 80+ 单元测试,作为 GPU 渲染数学正确性的 "哨兵"。
///
/// 严格按 shader 源码逐行对齐，不做任何 normalize / multiplier / clamp 之外的处理。
/// `feather` 参数全部按 shader 解释为 normalized [0, 1] 输入。
public enum MaskMath {

    // MARK: - 1. InnerGradientMask (shader line 11-41)

    /// 线性渐变在 `uv` 点的 coverage。
    ///
    /// 对应 shader `InnerGradientMask` line 26-31:
    /// ```metal
    /// const float2 delta = endPoint - startPoint;
    /// const float denominator = max(dot(delta, delta), 0.000001f);
    /// coverage = clamp(dot(uv - startPoint, delta) / denominator, 0.0f, 1.0f);
    /// ```
    /// 数学含义:把 `startPoint -> endPoint` 看成单位向量投影,投影值再 clamp 到 [0, 1]。
    /// - Parameters:
    ///   - uv: 像素中心归一化坐标 [0, 1]。
    ///   - start: 渐变起点 coverage = 0 处。
    ///   - end: 渐变终点 coverage = 1 处。
    /// - Returns: `[0, 1]` 区间的 coverage。
    public static func linearGradientCoverage(uv: SIMD2<Float>, start: SIMD2<Float>, end: SIMD2<Float>) -> Float {
        let delta = end - start
        let denominator = max(simd_dot(delta, delta), 0.000001)
        let t = simd_dot(uv - start, delta) / denominator
        return min(max(t, 0), 1)
    }

    /// 径向渐变在 `uv` 点的 coverage。
    ///
    /// 对应 shader `InnerGradientMask` line 32-38:
    /// ```metal
    /// const float startRadius = max(*value5Pointer, 0.0f);
    /// const float endRadius = max(*value6Pointer, startRadius + 0.000001f);
    /// const float distanceToCenter = distance(uv, center);
    /// coverage = 1.0f - smoothstep(startRadius, endRadius, distanceToCenter);
    /// ```
    /// 数学含义:中心处 coverage = 1,`endRadius` 之外 coverage = 0,中间按 smoothstep 衰减。
    public static func radialGradientCoverage(uv: SIMD2<Float>,
                                              center: SIMD2<Float>,
                                              innerRadius: Float,
                                              outerRadius: Float) -> Float {
        let startRadius = max(innerRadius, 0)
        let endRadius = max(outerRadius, startRadius + 0.000001)
        let distance = simd_distance(uv, center)
        return 1 - smoothstep(startRadius, endRadius, distance)
    }

    // MARK: - 2. InnerShapeMask (shader line 422-455)

    /// 矩形 coverage:在归一化矩形内 = 1,外 = 0,带 feather 软边。
    ///
    /// 对应 shader `InnerShapeMask` line 438-444 (rectangle 分支):
    /// ```metal
    /// const float2 local = (uv - origin) / size;
    /// const float2 edgeDistance = min(local, 1.0f - local);
    /// const float minEdge = min(edgeDistance.x, edgeDistance.y);
    /// const float featherWidth = max(feather * 0.5f, 0.000001f);
    /// coverage = smoothstep(0.0f, featherWidth, minEdge);
    /// coverage *= step(0.0f, local.x) * step(0.0f, local.y) * step(local.x, 1.0f) * step(local.y, 1.0f);
    /// ```
    /// - Parameters:
    ///   - point: 像素中心归一化坐标 [0, 1]。
    ///   - rect: `(x, y, w, h)` 全部 normalized [0, 1]。
    ///   - feather: normalized [0, 1] 的软边宽度;`feather=0` 时退化为硬边。
    public static func rectangleCoverage(point: SIMD2<Float>, rect: SIMD4<Float>, feather: Float) -> Float {
        let origin = SIMD2<Float>(rect.x, rect.y)
        let size = SIMD2<Float>(max(rect.z, 0.000001), max(rect.w, 0.000001))
        let local = (point - origin) / size
        let edgeDistance = SIMD2<Float>(min(local.x, 1 - local.x), min(local.y, 1 - local.y))
        let minEdge = min(edgeDistance.x, edgeDistance.y)
        let featherWidth = max(feather * 0.5, 0.000001)
        var coverage = smoothstep(0, featherWidth, minEdge)
        coverage *= step(0, local.x) * step(0, local.y) * step(local.x, 1) * step(local.y, 1)
        return coverage
    }

    /// 椭圆 coverage:在椭圆内 = 1,外 = 0,带 feather 软边。
    ///
    /// 对应 shader `InnerShapeMask` line 445-452 (ellipse 分支):
    /// ```metal
    /// const float2 center = origin + size * 0.5f;
    /// const float2 radius = size * 0.5f;
    /// const float2 normalized = (uv - center) / max(radius, float2(0.000001f));
    /// const float distanceValue = length(normalized);
    /// const float featherWidth = max(feather, 0.000001f);
    /// coverage = 1.0f - smoothstep(1.0f - featherWidth, 1.0f, distanceValue);
    /// ```
    /// - Parameters:
    ///   - point: 像素中心归一化坐标 [0, 1]。
    ///   - center: 椭圆中心归一化坐标。
    ///   - radii: 椭圆 x/y 半轴 (normalized [0, 1])。
    ///   - feather: normalized [0, 1] 的软边宽度。
    public static func ellipseCoverage(point: SIMD2<Float>,
                                       center: SIMD2<Float>,
                                       radii: SIMD2<Float>,
                                       feather: Float) -> Float {
        let radius = SIMD2<Float>(max(radii.x, 0.000001), max(radii.y, 0.000001))
        let normalized = (point - center) / radius
        let distanceValue = simd_length(normalized)
        let featherWidth = max(feather, 0.000001)
        return 1 - smoothstep(1 - featherWidth, 1, distanceValue)
    }

    /// 圆角矩形 coverage:SDF(带符号距离)判定 + feather 软边。
    ///
    /// 对应 shader `InnerShapeMask` line 453-462 (roundedRect 分支):
    /// ```metal
    /// const float2 local = (uv - origin) / size;
    /// const float2 center = local - 0.5f;
    /// const float2 q = abs(center) - 0.5f + cornerRadius;
    /// const float outsideDistance = length(float2(max(q.x, 0.0f), max(q.y, 0.0f)));
    /// const float insideDistance = min(max(q.x, q.y), 0.0f);
    /// const float sdf = outsideDistance + insideDistance;
    /// const float featherWidth = max(feather * 0.5f, 0.000001f);
    /// coverage = 1.0f - smoothstep(-featherWidth, featherWidth, sdf);
    /// ```
    /// - Parameters:
    ///   - point: 像素中心归一化坐标 [0, 1]。
    ///   - rect: `(x, y, w, h)` 全部 normalized [0, 1]。
    ///   - cornerRadius: 归一化圆角半径 ∈ [0, 0.5],相对 `min(width, height) * 0.5`。
    ///   - feather: normalized [0, 1] 的软边宽度。
    public static func roundedRectCoverage(point: SIMD2<Float>,
                                           rect: SIMD4<Float>,
                                           cornerRadius: Float,
                                           feather: Float) -> Float {
        let origin = SIMD2<Float>(rect.x, rect.y)
        let size = SIMD2<Float>(max(rect.z, 0.000001), max(rect.w, 0.000001))
        let local = (point - origin) / size
        let center = local - SIMD2<Float>(0.5, 0.5)
        let q = abs(center) - SIMD2<Float>(0.5, 0.5) + SIMD2<Float>(repeating: cornerRadius)
        let outsideDistance = simd_length(SIMD2<Float>(max(q.x, 0), max(q.y, 0)))
        let insideDistance = min(max(q.x, q.y), 0)
        let sdf = outsideDistance + insideDistance
        let featherWidth = max(feather * 0.5, 0.000001)
        return 1 - smoothstep(-featherWidth, featherWidth, sdf)
    }

    // MARK: - 3. InnerPathMask (shader line 472-525)

    /// 多边形 winding coverage:point 是否在 polygon 内,带 feather 软边。
    ///
    /// 对应 shader `InnerPathMask` line 457-525 的 ray-casting 算法:
    /// - evenOdd 模式:统计向右射线穿过的边数,奇数次 → inside
    /// - nonZero 模式:用 winding number,非零 → inside
    ///
    /// 单 subpath 接口;多 subpath 请使用 `polygonCoverage(point:subpaths:feather:)`。
    /// - Parameters:
    ///   - point: 像素中心归一化坐标。
    ///   - vertices: 闭合多边形顶点数组(首尾不重复,函数自动闭合到第一个点)。
    ///   - fillRule: `.evenOdd` 或 `.nonZero`,与 shader `metadata[2]` 对应。
    ///   - feather: normalized [0, 1] 的软边宽度(基于到最近边的距离)。
    /// - Returns: 内部为 1,外部为 0,边缘按 smoothstep 平滑。
    public static func polygonCoverage(point: SIMD2<Float>,
                                       vertices: [SIMD2<Float>],
                                       fillRule: MaskPathFillRule = .nonZero,
                                       feather: Float = 0) -> Float {
        guard vertices.count >= 3 else { return 0 }
        let inside = pathInsideTest(point: point, vertices: vertices, fillRule: fillRule)
        if feather > 0 {
            let distance = pathDistanceToPolygon(point: point, vertices: vertices)
            let low: Float = 0
            let high: Float = max(feather, 0.000001)
            let softened = inside ? 1.0 : smoothstep(high, low, distance)
            return softened
        }
        return inside ? 1 : 0
    }

    /// 多 subpath 版本的 winding coverage。
    ///
    /// 对应 shader `InnerPathMask` line 495-519:遍历每个 subpath 的边,
    /// 按 fillRule 累计 ray crossing / winding number。
    public static func polygonCoverage(point: SIMD2<Float>,
                                       subpaths: [[SIMD2<Float>]],
                                       fillRule: MaskPathFillRule = .nonZero,
                                       feather: Float = 0) -> Float {
        let validSubpaths = subpaths.filter { $0.count >= 3 }
        guard !validSubpaths.isEmpty else { return 0 }

        var evenOddInside = false
        var windingNumber = 0
        for subpath in validSubpaths {
            for edgeIndex in 0..<subpath.count {
                let a = subpath[edgeIndex]
                let b = subpath[(edgeIndex + 1) % subpath.count]
                guard pathEdgeCrossesRay(point: point, a: a, b: b) else { continue }
                let intersectionX = pathRayIntersectionX(point: point, a: a, b: b)
                guard point.x < intersectionX else { continue }
                if fillRule == .evenOdd {
                    evenOddInside.toggle()
                } else if b.y > a.y {
                    windingNumber += 1
                } else {
                    windingNumber -= 1
                }
            }
        }
        let inside = fillRule == .evenOdd ? evenOddInside : (windingNumber != 0)

        if feather > 0 {
            var minDistance = Float.infinity
            for subpath in validSubpaths {
                let d = pathDistanceToPolygon(point: point, vertices: subpath)
                if d < minDistance { minDistance = d }
            }
            let high: Float = max(feather, 0.000001)
            return inside ? 1.0 : smoothstep(high, 0, minDistance)
        }
        return inside ? 1 : 0
    }

    // MARK: - 4. InnerMaskRegionBlend (shader line 372-420)

    /// base / effect / mask 三合一 blend:`mix(base, effect, coverage × opacity)`。
    ///
    /// 对应 shader `InnerMaskRegionBlend` line 400-402 (默认 mix 模式):
    /// ```metal
    /// mask *= half(*opacityPointer);
    /// half4 output = mix(base, effect, mask);
    /// ```
    /// 不处理 feather / invert / 其他 blendMode (replace/add/multiply/subtract)
    /// —— 那些语义属于组合 kernel `MaskRegionBlend` 的封装,本函数只暴露
    /// 核心的 `mix(base, effect, mask)` 公式,作为 CPU 哨兵。
    public static func regionBlend(base: SIMD4<Float>,
                                   effect: SIMD4<Float>,
                                   coverage: Float,
                                   opacity: Float) -> SIMD4<Float> {
        let mask = coverage * opacity
        return simd_mix(base, effect, SIMD4<Float>(repeating: mask))
    }

    // MARK: - 5. InnerMaskCoverageBlend (shader line 290-322)

    /// mask texture 的 RGB → 单通道 coverage。
    ///
    /// 对应 shader `extractInnerMaskComponentValue` line 324-333 (`.luminance` 段):
    /// ```metal
    /// case 0: return color.a;       // .alpha:需要 alpha,见 coverageFromRGBA
    /// case 1: return color.r;       // .red
    /// case 2: return color.g;       // .green
    /// case 3: return color.b;       // .blue
    /// case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));  // Rec.601 luminance
    /// ```
    /// 本函数接收 `SIMD3<Float>` 表示 RGB;如果需要 alpha,请使用 `coverageFromRGBA`。
    /// `MaskComponent.alpha` 在本函数中被视为 0(因为 RGB 没有 alpha 信息)。
    /// `MaskComponent.luminance` 使用 **Rec.601** 权重 (0.299, 0.587, 0.114)。
    public static func coverageFromRGB(rgb: SIMD3<Float>, component: MaskComponent) -> Float {
        switch component {
        case .alpha:
            return 0  // RGB 没有 alpha,严格按"未提供"语义返回 0
        case .red:
            return rgb.x
        case .green:
            return rgb.y
        case .blue:
            return rgb.z
        case .luminance:
            return rgb.x * 0.299 + rgb.y * 0.587 + rgb.z * 0.114
        }
    }

    /// 4 通道 RGBA → 单通道 coverage(把 alpha 通道一并传入)。
    public static func coverageFromRGBA(rgba: SIMD4<Float>, component: MaskComponent) -> Float {
        switch component {
        case .alpha:
            return rgba.w
        case .red:
            return rgba.x
        case .green:
            return rgba.y
        case .blue:
            return rgba.z
        case .luminance:
            return rgba.x * 0.299 + rgba.y * 0.587 + rgba.z * 0.114
        }
    }

    // MARK: - 6. InnerMaskCoverageExtract (shader line 335-359)

    /// 提取 mask 通道:从输入 texture 选定 component、quantize 到 [0, 1]。
    ///
    /// 对应 shader `InnerMaskCoverageExtract` line 346-357:
    /// ```metal
    /// half coverage = extractInnerMaskComponentValue(input, int(*componentPointer));
    /// if (*invertPointer > 0.5f) {
    ///     coverage = 1.0h - coverage;
    /// }
    /// const half feather = half(*featherPointer);
    /// if (feather > 0.0h) {
    ///     const half low = max(0.0h, 0.5h - feather * 0.5h);
    ///     const half high = min(1.0h, 0.5h + feather * 0.5h);
    ///     coverage = smoothstep(low, high, coverage);
    /// }
    /// coverage = clamp(coverage * half(*opacityPointer), 0.0h, 1.0h);
    /// ```
    public static func extractCoverage(rgba: SIMD4<Float>,
                                       component: MaskComponent,
                                       invert: Bool,
                                       feather: Float,
                                       opacity: Float) -> Float {
        var coverage = coverageFromRGBA(rgba: rgba, component: component)
        if invert {
            coverage = 1 - coverage
        }
        if feather > 0 {
            let low = max(0, 0.5 - feather * 0.5)
            let high = min(1, 0.5 + feather * 0.5)
            coverage = smoothstep(low, high, coverage)
        }
        let result = coverage * opacity
        return min(max(result, 0), 1)
    }

    /// 不带 feather 的精简版(对应 `extractCoverage` 但 `featherPointer == 0` 的快速路径)。
    public static func extractCoverage(rgba: SIMD4<Float>,
                                       component: MaskComponent,
                                       invert: Bool,
                                       opacity: Float) -> Float {
        var coverage = coverageFromRGBA(rgba: rgba, component: component)
        if invert {
            coverage = 1 - coverage
        }
        let result = coverage * opacity
        return min(max(result, 0), 1)
    }

    // MARK: - 辅助:Path 数学 (mirror of shader line 457-470)

    /// 单边 ray crossing 判断(mirror of shader `innerPathEdgeCrossesRay` line 457-459)。
    @inlinable
    static func pathEdgeCrossesRay(point: SIMD2<Float>, a: SIMD2<Float>, b: SIMD2<Float>) -> Bool {
        return (a.y > point.y) != (b.y > point.y)
    }

    /// 单边 ray 交点 X 坐标(mirror of shader `innerPathRayIntersectionX` line 461-464)。
    @inlinable
    static func pathRayIntersectionX(point: SIMD2<Float>, a: SIMD2<Float>, b: SIMD2<Float>) -> Float {
        let denominator = b.y - a.y
        let safeDenom = abs(denominator) < 0.0000001 ? 0.0000001 : denominator
        return (b.x - a.x) * (point.y - a.y) / safeDenom + a.x
    }

    /// 点到线段距离(mirror of shader `innerPathDistanceToSegment` line 466-470)。
    /// 仅供 polygon feather 计算使用,与 coverage 判定本身无关。
    static func pathDistanceToSegment(point: SIMD2<Float>, a: SIMD2<Float>, b: SIMD2<Float>) -> Float {
        let ab = b - a
        let denom = max(simd_dot(ab, ab), 0.0000001)
        let t = min(max(simd_dot(point - a, ab) / denom, 0), 1)
        return simd_distance(point, a + ab * t)
    }

    /// 点到闭合多边形所有边的最小距离。
    static func pathDistanceToPolygon(point: SIMD2<Float>, vertices: [SIMD2<Float>]) -> Float {
        guard vertices.count >= 3 else { return .infinity }
        var minDistance = Float.infinity
        for index in 0..<vertices.count {
            let a = vertices[index]
            let b = vertices[(index + 1) % vertices.count]
            let d = pathDistanceToSegment(point: point, a: a, b: b)
            if d < minDistance { minDistance = d }
        }
        return minDistance
    }

    /// 单 subpath 的 inside 测试(mirror of shader 内层循环)。
    private static func pathInsideTest(point: SIMD2<Float>, vertices: [SIMD2<Float>], fillRule: MaskPathFillRule) -> Bool {
        var evenOddInside = false
        var windingNumber = 0
        for index in 0..<vertices.count {
            let a = vertices[index]
            let b = vertices[(index + 1) % vertices.count]
            guard pathEdgeCrossesRay(point: point, a: a, b: b) else { continue }
            let intersectionX = pathRayIntersectionX(point: point, a: a, b: b)
            guard point.x < intersectionX else { continue }
            if fillRule == .evenOdd {
                evenOddInside.toggle()
            } else if b.y > a.y {
                windingNumber += 1
            } else {
                windingNumber -= 1
            }
        }
        return fillRule == .evenOdd ? evenOddInside : (windingNumber != 0)
    }

    // MARK: - 辅助:math primitives

    /// `step(edge, x)` —— 返回 `x >= edge ? 1 : 0`,mirror of shader `step()`。
    @inlinable
    static func step(_ edge: Float, _ x: Float) -> Float {
        return x >= edge ? 1 : 0
    }

    /// `smoothstep(edge0, edge1, x)` —— 与 Metal Shading Language `smoothstep` 一致:
    /// ```metal
    /// t = clamp((x - edge0) / (edge1 - edge0), 0, 1);
    /// return t * t * (3 - 2 * t);
    /// ```
    @inlinable
    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
