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

static float curveCubic(float value, constant float *points, int count, bool extrapolates) {
    if (count < 2) return value;
    if (value < points[0]) return extrapolates ? points[1] + (value - points[0]) * curveSlope(points, count, 0) : points[1];
    if (value > points[(count - 1) * 2]) {
        return extrapolates ? points[(count - 1) * 2 + 1] + (value - points[(count - 1) * 2]) * curveSlope(points, count, count - 1)
                            : points[(count - 1) * 2 + 1];
    }
    int index = 0;
    while (index < count - 2 && points[(index + 1) * 2] < value) ++index;
    const float x0 = points[index * 2], y0 = points[index * 2 + 1];
    const float x1 = points[(index + 1) * 2], y1 = points[(index + 1) * 2 + 1];
    const float h = x1 - x0;
    if (h <= 0) return y0;
    const float t = clamp((value - x0) / h, 0.0f, 1.0f), t2 = t * t, t3 = t2 * t;
    const float y = (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * h * curveSlope(points, count, index)
        + (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * h * curveSlope(points, count, index + 1);
    return clamp(y, min(y0, y1), max(y0, y1));
}

static float curveValue(float value, constant float *points, int count, bool legacy, bool cubic, bool extrapolates) {
    if (count < 2) return value;
    if (legacy) return curveInterpolationLegacy(value, points, count);
    return cubic ? curveCubic(value, points, count, extrapolates) : curveInterpolation(value, points, count, extrapolates);
}

static half4 c7ApplyCurves(half4 input, float4 counts, constant float *rgbPoints,
                         constant float *redPoints, constant float *greenPoints, constant float *bluePoints,
                         bool legacy, bool cubic, bool extrapolates, bool channelsFirst) {
    // 新模式按直色值调节后恢复预乘；旧模式保留已持久化像素语义。
    const float alpha = float(input.a);
    if (cubic && alpha <= 0) return half4(0);
    float3 color = float3(input.rgb);
    if (cubic) color /= alpha;
    if (!channelsFirst) {
        color.r = curveValue(color.r, rgbPoints, int(counts.x), legacy, cubic, extrapolates);
        color.g = curveValue(color.g, rgbPoints, int(counts.x), legacy, cubic, extrapolates);
        color.b = curveValue(color.b, rgbPoints, int(counts.x), legacy, cubic, extrapolates);
    }
    color.r = curveValue(color.r, redPoints, int(counts.y), legacy, cubic, extrapolates);
    color.g = curveValue(color.g, greenPoints, int(counts.z), legacy, cubic, extrapolates);
    color.b = curveValue(color.b, bluePoints, int(counts.w), legacy, cubic, extrapolates);
    if (channelsFirst) {
        color.r = curveValue(color.r, rgbPoints, int(counts.x), legacy, cubic, extrapolates);
        color.g = curveValue(color.g, rgbPoints, int(counts.x), legacy, cubic, extrapolates);
        color.b = curveValue(color.b, rgbPoints, int(counts.x), legacy, cubic, extrapolates);
    }
    if (cubic) color *= alpha;
    return half4(half3(color), input.a);
}

kernel void C7Curves(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float4 &pointCounts [[buffer(0)]],
                     constant float *rgbPoints [[buffer(1)]],
                     constant float *redPoints [[buffer(2)]],
                     constant float *greenPoints [[buffer(3)]],
                     constant float *bluePoints [[buffer(4)]],
                     constant float *extrapolation [[buffer(5)]],
                     constant float *compositionOrder [[buffer(6)]],
                     uint2 grid [[thread_position_in_grid]]) {
    outputTexture.write(c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                      false, false, extrapolation[0] >= 0.5f, compositionOrder[0] >= 0.5f), grid);
}

kernel void C7CurvesCubic(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float4 &pointCounts [[buffer(0)]],
                     constant float *rgbPoints [[buffer(1)]],
                     constant float *redPoints [[buffer(2)]],
                     constant float *greenPoints [[buffer(3)]],
                     constant float *bluePoints [[buffer(4)]],
                     constant float *extrapolation [[buffer(5)]],
                     constant float *compositionOrder [[buffer(6)]],
                     uint2 grid [[thread_position_in_grid]]) {
    outputTexture.write(c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                      false, true, extrapolation[0] >= 0.5f, compositionOrder[0] >= 0.5f), grid);
}

kernel void C7CurvesLegacy(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float4 &pointCounts [[buffer(0)]],
                     constant float *rgbPoints [[buffer(1)]],
                     constant float *redPoints [[buffer(2)]],
                     constant float *greenPoints [[buffer(3)]],
                     constant float *bluePoints [[buffer(4)]],
                     uint2 grid [[thread_position_in_grid]]) {
    outputTexture.write(c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                      true, false, false, false), grid);
}

kernel void C7CurvesLegacyOrdered(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float4 &pointCounts [[buffer(0)]],
                     constant float *rgbPoints [[buffer(1)]],
                     constant float *redPoints [[buffer(2)]],
                     constant float *greenPoints [[buffer(3)]],
                     constant float *bluePoints [[buffer(4)]],
                     constant float *compositionOrder [[buffer(5)]],
                     uint2 grid [[thread_position_in_grid]]) {
    outputTexture.write(c7ApplyCurves(inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints,
                                      true, false, false, compositionOrder[0] >= 0.5f), grid);
}
