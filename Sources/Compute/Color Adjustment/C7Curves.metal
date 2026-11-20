//
//  C7Curves.metal
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

#include <metal_stdlib>
using namespace metal;

float curveInterpolation(float value, constant float* points, int pointCount, bool extrapolates) {
    if (pointCount == 0) return value;
    if (pointCount == 1) return points[1];
    int upperIndex = 1;
    while (upperIndex < pointCount && points[upperIndex * 2] < value) {
        upperIndex++;
    }
    upperIndex = min(upperIndex, pointCount - 1);
    const int lowerIndex = max(0, upperIndex - 1);
    float x0 = points[lowerIndex * 2];
    float y0 = points[lowerIndex * 2 + 1];
    float x1 = points[upperIndex * 2];
    float y1 = points[upperIndex * 2 + 1];
    if (x1 == x0) return y0;
    float t = (value - x0) / (x1 - x0);
    if (!extrapolates) t = clamp(t, 0.0, 1.0);
    return mix(y0, y1, t);
}

float curveInterpolationLegacy(float value, constant float* points, int pointCount) {
    if (pointCount == 0) return value;
    if (pointCount == 1) return points[1];
    if (pointCount == 2) {
        float x0 = points[0];
        float y0 = points[1];
        float x1 = points[2];
        float y1 = points[3];
        if (x1 == x0) return y0;
        float t = clamp((value - x0) / (x1 - x0), 0.0, 1.0);
        return mix(y0, y1, t);
    }
    int i = 0;
    while (i < pointCount - 1 && points[i * 2] < value) {
        i++;
    }
    if (i == 0) {
        const float x0 = points[0];
        const float x1 = points[2];
        if (x1 == x0) return points[1];
        const float t = (value - x0) / (x1 - x0);
        return mix(points[1], points[3], t);
    }
    if (i == pointCount - 1) {
        const int lower = pointCount - 2;
        const float x0 = points[lower * 2];
        const float y0 = points[lower * 2 + 1];
        const float x1 = points[i * 2];
        const float y1 = points[i * 2 + 1];
        if (x1 == x0) return y0;
        return mix(y0, y1, (value - x0) / (x1 - x0));
    }
    const float x0 = points[i * 2];
    const float y0 = points[i * 2 + 1];
    const float x1 = points[(i + 1) * 2];
    const float y1 = points[(i + 1) * 2 + 1];
    if (x1 == x0) return y0;
    return mix(y0, y1, (value - x0) / (x1 - x0));
}

// 保持形状的Hermite切线；转折点斜率为0，不产生控制点之间的亮暗过冲。
static float curveSlope(constant float *points, int count, int index) {
    const int left = max(0, index - 1);
    const int right = min(count - 2, index);
    const float h0 = points[(left + 1) * 2] - points[left * 2];
    const float h1 = points[(right + 1) * 2] - points[right * 2];
    if (h0 <= 0 || h1 <= 0) return 0;
    const float a = (points[(left + 1) * 2 + 1] - points[left * 2 + 1]) / h0;
    const float b = (points[(right + 1) * 2 + 1] - points[right * 2 + 1]) / h1;
    return a * b > 0 ? 2.0f / (1.0f / a + 1.0f / b) : 0.0f;
}

static float curveTangent(constant float *points, int count, int index, constant float *preparedTangents, int offset) {
    return offset > 0 ? preparedTangents[offset + index] : curveSlope(points, count, index);
}

static float curveCubic(float value, constant float *points, int count, bool extrapolates,
                        constant float *preparedTangents, int offset) {
    if (count < 2) return value;
    if (offset == -1 && isfinite(value)) return extrapolates ? value : clamp(value, 0.0f, 1.0f);
    if (value < points[0]) return extrapolates ? points[1] + (value - points[0]) * curveTangent(points, count, 0, preparedTangents, offset) : points[1];
    if (value > points[(count - 1) * 2]) {
        return extrapolates ? points[(count - 1) * 2 + 1] + (value - points[(count - 1) * 2]) * curveTangent(points, count, count - 1, preparedTangents, offset)
        : points[(count - 1) * 2 + 1];
    }
    int index = 0;
    // 仅在网格中最多一个内部控制点的通道启用；严格比较保留旧段边界。
    const int table = offset > 0 && count == 32 ? offset + count : 0;
    const uint binCount = table > 0 ? uint(preparedTangents[table]) : 0;
    if (offset > 0 && count == 9) {
        for (int knot = 1; knot < 8; ++knot) index += int(points[knot * 2] < value);
    } else if (binCount > 0 && isfinite(value)) {
        const uint bin = min(uint(value * float(binCount)), binCount - 1);
        const uint entries = uint(preparedTangents[table + 1 + (bin >> 2)]);
        index = int((entries >> ((bin & 3) * 5)) & 31);
        index += int(points[(index + 1) * 2] < value);
    } else {
        while (index < count - 2 && points[(index + 1) * 2] < value) ++index;
    }
    const float x0 = points[index * 2], y0 = points[index * 2 + 1];
    const float x1 = points[(index + 1) * 2], y1 = points[(index + 1) * 2 + 1];
    const float h = x1 - x0;
    if (h <= 0) return y0;
    const float t = clamp((value - x0) / h, 0.0f, 1.0f), t2 = t * t, t3 = t2 * t;
    const float m0 = curveTangent(points, count, index, preparedTangents, offset);
    const float m1 = curveTangent(points, count, index + 1, preparedTangents, offset);
    const float y = (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * h * m0
        + (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * h * m1;
    return clamp(y, min(y0, y1), max(y0, y1));
}

static float curveValue(float value, constant float *points, int count, bool legacy, bool cubic, bool extrapolates,
                        constant float *preparedTangents, int offset) {
    if (count < 2) return value;
    if (legacy) return curveInterpolationLegacy(value, points, count);
    return cubic ? curveCubic(value, points, count, extrapolates, preparedTangents, offset) : curveInterpolation(value, points, count, extrapolates);
}

static bool curveIsUnitIdentity(constant float *points, int count) {
    return count < 2 || (count == 2 && points[0] == 0.0f && points[1] == 0.0f && points[2] == 1.0f && points[3] == 1.0f);
}

static float4 c7ApplyCurves(float4 input, float4 counts, constant float *rgbPoints,
                            constant float *redPoints, constant float *greenPoints, constant float *bluePoints,
                            bool legacy, bool cubic, bool extrapolates, bool channelsFirst,
                            constant float *preparedTangents = nullptr) {
    // 新模式按直色值调节后恢复预乘；旧模式保留已持久化像素语义。
    const float alpha = float(input.a);
    if (cubic && alpha <= 0) return float4(0);
    float3 color = float3(input.rgb);
    if (cubic) color /= alpha;
    // 空曲线恒等；单位曲线仅在其有效域或显式线性外推时省去往返舍入。
    if (all(counts < float4(2))) return input;
    if (curveIsUnitIdentity(rgbPoints, int(counts.x)) && curveIsUnitIdentity(redPoints, int(counts.y))
        && curveIsUnitIdentity(greenPoints, int(counts.z)) && curveIsUnitIdentity(bluePoints, int(counts.w))
        && ((!legacy && extrapolates) || (all(color >= 0.0f) && all(color <= 1.0f)))) return input;
    const int4 offsets = cubic
        ? int4(preparedTangents[0], preparedTangents[1], preparedTangents[2], preparedTangents[3])
        : int4(0);
    if (!channelsFirst) {
        color.r = curveValue(color.r, rgbPoints, int(counts.x), legacy, cubic, extrapolates, preparedTangents, offsets.x);
        color.g = curveValue(color.g, rgbPoints, int(counts.x), legacy, cubic, extrapolates, preparedTangents, offsets.x);
        color.b = curveValue(color.b, rgbPoints, int(counts.x), legacy, cubic, extrapolates, preparedTangents, offsets.x);
    }
    color.r = curveValue(color.r, redPoints, int(counts.y), legacy, cubic, extrapolates, preparedTangents, offsets.y);
    color.g = curveValue(color.g, greenPoints, int(counts.z), legacy, cubic, extrapolates, preparedTangents, offsets.z);
    color.b = curveValue(color.b, bluePoints, int(counts.w), legacy, cubic, extrapolates, preparedTangents, offsets.w);
    if (channelsFirst) {
        color.r = curveValue(color.r, rgbPoints, int(counts.x), legacy, cubic, extrapolates, preparedTangents, offsets.x);
        color.g = curveValue(color.g, rgbPoints, int(counts.x), legacy, cubic, extrapolates, preparedTangents, offsets.x);
        color.b = curveValue(color.b, rgbPoints, int(counts.x), legacy, cubic, extrapolates, preparedTangents, offsets.x);
    }
    if (cubic) color *= alpha;
    return float4(color, input.a);
}

kernel void C7Curves(texture2d<float, access::write> outputTexture [[texture(0)]],
                     texture2d<float, access::read> inputTexture [[texture(1)]],
                     constant float4 &pointCounts [[buffer(0)]],
                     constant float *rgbPoints [[buffer(1)]],
                     constant float *redPoints [[buffer(2)]],
                     constant float *greenPoints [[buffer(3)]],
                     constant float *bluePoints [[buffer(4)]],
                     constant float *extrapolation [[buffer(5)]],
                     constant float *compositionOrder [[buffer(6)]],
                     constant float &halfOutput [[buffer(7)]],
                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                        false, false, extrapolation[0] >= 0.5f, compositionOrder[0] >= 0.5f);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}

kernel void C7CurvesCubic(texture2d<float, access::write> outputTexture [[texture(0)]],
                          texture2d<float, access::read> inputTexture [[texture(1)]],
                          constant float4 &pointCounts [[buffer(0)]],
                          constant float *rgbPoints [[buffer(1)]],
                          constant float *redPoints [[buffer(2)]],
                          constant float *greenPoints [[buffer(3)]],
                          constant float *bluePoints [[buffer(4)]],
                          constant float *extrapolation [[buffer(5)]],
                          constant float *compositionOrder [[buffer(6)]],
                          constant float &halfOutput [[buffer(7)]],
                          constant float *preparedTangents [[buffer(8)]],
                          uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                        false, true, extrapolation[0] >= 0.5f, compositionOrder[0] >= 0.5f, preparedTangents);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}

kernel void C7CurvesLegacy(texture2d<float, access::write> outputTexture [[texture(0)]],
                           texture2d<float, access::read> inputTexture [[texture(1)]],
                           constant float4 &pointCounts [[buffer(0)]],
                           constant float *rgbPoints [[buffer(1)]],
                           constant float *redPoints [[buffer(2)]],
                           constant float *greenPoints [[buffer(3)]],
                           constant float *bluePoints [[buffer(4)]],
                           constant float &halfOutput [[buffer(7)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                        true, false, false, false);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}

kernel void C7CurvesLegacyOrdered(texture2d<float, access::write> outputTexture [[texture(0)]],
                                  texture2d<float, access::read> inputTexture [[texture(1)]],
                                  constant float4 &pointCounts [[buffer(0)]],
                                  constant float *rgbPoints [[buffer(1)]],
                                  constant float *redPoints [[buffer(2)]],
                                  constant float *greenPoints [[buffer(3)]],
                                  constant float *bluePoints [[buffer(4)]],
                                  constant float *compositionOrder [[buffer(5)]],
                                  constant float &halfOutput [[buffer(7)]],
                                  uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                        true, false, false, compositionOrder[0] >= 0.5f);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
