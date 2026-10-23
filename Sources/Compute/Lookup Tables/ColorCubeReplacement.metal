//
//  ColorCubeReplacement.metal
//  Harbeth
//
//  Created by Condy on 2026/10/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void colorCubeReplacementPrepare(texture2d<half, access::write> output [[texture(0)]],
                                       texture2d<half, access::read> input [[texture(1)]],
                                       uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    // 原 CUBE 直接映射 RGB，不按 alpha 解除预乘；临时不透明域保留这一合同。
    output.write(half4(clamp(input.read(p).rgb, half3(0), half3(1)), 1), p);
}

kernel void colorCubeReplacementMix(texture2d<half, access::write> output [[texture(0)]],
                                   texture2d<half, access::read> input [[texture(1)]],
                                   texture2d<half, access::read> processed [[texture(2)]],
                                   constant float &intensity [[buffer(0)]],
                                   constant float &domainPolicy [[buffer(1)]],
                                   uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    const half4 original = input.read(p);
    if (intensity <= 0 || (domainPolicy >= 0.5f &&
        (any(original.rgb < half3(0)) || any(original.rgb > half3(1))))) {
        output.write(original, p);
        return;
    }
    output.write(half4(mix(original.rgb, processed.read(p).rgb, half(clamp(intensity, 0.0f, 1.0f))), original.a), p);
}

static float colorCubeAtomicCurve(float value, constant float *points, int count) {
    int upper = 1;
    while (upper < count && points[upper * 2] < value) ++upper;
    upper = min(upper, count - 1);
    const int lower = max(0, upper - 1);
    const float x0 = points[lower * 2], x1 = points[upper * 2];
    if (x1 == x0) return points[lower * 2 + 1];
    const float t = clamp((value - x0) / (x1 - x0), 0.0f, 1.0f);
    return mix(points[lower * 2 + 1], points[upper * 2 + 1], t);
}

kernel void colorCubeReplacementCurveMatrixCurve(texture2d<half, access::write> output [[texture(0)]],
                                                texture2d<half, access::read> input [[texture(1)]],
                                                constant float &intensity [[buffer(0)]],
                                                constant float &domainPolicy [[buffer(1)]],
                                                constant float *counts [[buffer(2)]],
                                                constant float *points [[buffer(3)]],
                                                constant float4x4 &matrixValue [[buffer(4)]],
                                                constant float4 &vectorValue [[buffer(5)]],
                                                uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    const half4 original = input.read(p);
    if (intensity <= 0 || (domainPolicy >= 0.5f &&
        (any(original.rgb < half3(0)) || any(original.rgb > half3(1))))) {
        output.write(original, p);
        return;
    }
    int offsets[6];
    offsets[0] = 0;
    for (int i = 1; i < 6; ++i) offsets[i] = offsets[i - 1] + int(counts[i - 1]) * 2;
    const float3 source = clamp(float3(original.rgb), 0.0f, 1.0f);
    // 每个原子边界保留 half 舍入，与半浮点中间纹理中的执行顺序一致。
    const half3 first = half3(clamp(float3(
        colorCubeAtomicCurve(source.r, points + offsets[0], int(counts[0])),
        colorCubeAtomicCurve(source.g, points + offsets[1], int(counts[1])),
        colorCubeAtomicCurve(source.b, points + offsets[2], int(counts[2]))), 0.0f, 1.0f));
    const half4x4 m = half4x4(matrixValue);
    const half4 v = half4(vectorValue);
    const half3 transformed = half3(
        first.r * m[0][0] + first.g * m[0][1] + first.b * m[0][2] + m[0][3] + v[0],
        first.r * m[1][0] + first.g * m[1][1] + first.b * m[1][2] + m[1][3] + v[1],
        first.r * m[2][0] + first.g * m[2][1] + first.b * m[2][2] + m[2][3] + v[2]);
    const half3 mapped = half3(clamp(float3(
        colorCubeAtomicCurve(float(transformed.r), points + offsets[3], int(counts[3])),
        colorCubeAtomicCurve(float(transformed.g), points + offsets[4], int(counts[4])),
        colorCubeAtomicCurve(float(transformed.b), points + offsets[5], int(counts[5]))), 0.0f, 1.0f));
    output.write(half4(mix(original.rgb, mapped, half(clamp(intensity, 0.0f, 1.0f))), original.a), p);
}
