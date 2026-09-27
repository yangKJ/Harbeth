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

static half4 c7ApplyCurves(
    half4 input,
    float4 pointCounts,
    constant float *rgbPoints,
    constant float *redPoints,
    constant float *greenPoints,
    constant float *bluePoints,
    bool usesLegacyInterpolation,
    bool extrapolates
) {
    const int rgbPointCount = int(pointCounts.x);
    const int redPointCount = int(pointCounts.y);
    const int greenPointCount = int(pointCounts.z);
    const int bluePointCount = int(pointCounts.w);
    float red = float(input.r);
    float green = float(input.g);
    float blue = float(input.b);

    if (rgbPointCount >= 2) {
        red = usesLegacyInterpolation
            ? curveInterpolationLegacy(red, rgbPoints, rgbPointCount)
            : curveInterpolation(red, rgbPoints, rgbPointCount, extrapolates);
        green = usesLegacyInterpolation
            ? curveInterpolationLegacy(green, rgbPoints, rgbPointCount)
            : curveInterpolation(green, rgbPoints, rgbPointCount, extrapolates);
        blue = usesLegacyInterpolation
            ? curveInterpolationLegacy(blue, rgbPoints, rgbPointCount)
            : curveInterpolation(blue, rgbPoints, rgbPointCount, extrapolates);
    }
    if (redPointCount >= 2) {
        red = usesLegacyInterpolation
            ? curveInterpolationLegacy(red, redPoints, redPointCount)
            : curveInterpolation(red, redPoints, redPointCount, extrapolates);
    }
    if (greenPointCount >= 2) {
        green = usesLegacyInterpolation
            ? curveInterpolationLegacy(green, greenPoints, greenPointCount)
            : curveInterpolation(green, greenPoints, greenPointCount, extrapolates);
    }
    if (bluePointCount >= 2) {
        blue = usesLegacyInterpolation
            ? curveInterpolationLegacy(blue, bluePoints, bluePointCount)
            : curveInterpolation(blue, bluePoints, bluePointCount, extrapolates);
    }
    return half4(half3(red, green, blue), input.a);
}

kernel void C7Curves(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float4 &pointCounts [[buffer(0)]],
                     constant float *rgbPoints [[buffer(1)]],
                     constant float *redPoints [[buffer(2)]],
                     constant float *greenPoints [[buffer(3)]],
                     constant float *bluePoints [[buffer(4)]],
                     constant float *extrapolation [[buffer(5)]],
                     uint2 grid [[thread_position_in_grid]]) {
    outputTexture.write(c7ApplyCurves(
        inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints, false,
        extrapolation[0] >= 0.5f
    ), grid);
}

kernel void C7CurvesLegacy(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float4 &pointCounts [[buffer(0)]],
                           constant float *rgbPoints [[buffer(1)]],
                           constant float *redPoints [[buffer(2)]],
                           constant float *greenPoints [[buffer(3)]],
                           constant float *bluePoints [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
    outputTexture.write(c7ApplyCurves(
        inputTexture.read(grid), pointCounts, rgbPoints, redPoints, greenPoints, bluePoints, true, false
    ), grid);
}
