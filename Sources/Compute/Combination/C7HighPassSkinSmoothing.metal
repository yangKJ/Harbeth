//
//  C7HighPassSkinSmoothing.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

static inline half highPassOverlay(half base, half blend) {
    return base <= half(0.5)
        ? half(2.0) * base * blend
        : half(1.0) - half(2.0) * (half(1.0) - base) * (half(1.0) - blend);
}

static inline half highPassHardLightSelf(half value) {
    return value <= half(0.5)
        ? half(2.0) * value * value
        : half(1.0) - half(2.0) * (half(1.0) - value) * (half(1.0) - value);
}

static inline half highPassToneCurve(half value, half inputMid, half outputMid) {
    if (value <= inputMid) {
        return value * outputMid / inputMid;
    }
    return outputMid + (value - inputMid) * (half(1.0) - outputMid) / (half(1.0) - inputMid);
}

static inline half highPassChannelOverlay(half3 color) {
    const half green = color.g * half(0.5);
    const half blue = color.b * half(0.5);
    return highPassOverlay(green, blue);
}

static inline half3 highPassStraightColor(texture2d<half, access::read> texture, uint2 coordinate) {
    const half4 color = texture.read(coordinate);
    return color.a > half(0.0) ? color.rgb / color.a : half3(0.0);
}

kernel void C7HighPassSkinChannelOverlay(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    const half4 source = inputTexture.read(gid);
    const half3 straightColor = source.a > half(0.0)
        ? source.rgb / source.a
        : half3(0.0);
    const half guide = highPassChannelOverlay(straightColor);
    outputTexture.write(half4(guide, guide, guide, half(1.0)), gid);
}

kernel void C7HighPassSkinSmoothingComposite(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<half, access::read> blurredGuideTexture [[texture(2)]],
    constant float *amount [[buffer(0)]],
    constant float *detailThreshold [[buffer(1)]],
    constant float *detailTransition [[buffer(2)]],
    constant float *sharpnessFactor [[buffer(3)]],
    constant float *toneCurveInputMidpoint [[buffer(4)]],
    constant float *toneCurveOutputMidpoint [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    const half4 source = inputTexture.read(gid);
    const half smoothingAmount = half(clamp(*amount, 0.0f, 1.0f));
    if (smoothingAmount <= half(0.0) || source.a <= half(0.0)) {
        outputTexture.write(source, gid);
        return;
    }

    const half3 straightColor = source.rgb / source.a;

    // 扩展动态范围像素保持原值，避免审美容错逻辑截断 HDR/EDR 数据。
    if (any(straightColor < half3(0.0)) || any(straightColor > half3(1.0))) {
        outputTexture.write(source, gid);
        return;
    }

    const half guide = highPassChannelOverlay(straightColor);
    const half blurredGuide = blurredGuideTexture.read(gid).r;
    half detail = clamp(guide - blurredGuide + half(0.5), half(0.0), half(1.0));
    detail = highPassHardLightSelf(detail);
    detail = highPassHardLightSelf(detail);
    detail = highPassHardLightSelf(detail);

    const half threshold = half(clamp(*detailThreshold, 0.0f, 1.0f));
    const half transition = half(max(*detailTransition, 1.0f / 255.0f));
    const half detailProtection = clamp((detail - threshold) / transition, half(0.0), half(1.0));
    const half sharpness = half(clamp(*sharpnessFactor, 0.0f, 1.0f));
    const half inputMidpoint = half(clamp(*toneCurveInputMidpoint, 1.0f / 255.0f, 1.0f - 1.0f / 255.0f));
    const half outputMidpoint = half(clamp(*toneCurveOutputMidpoint, 0.0f, 1.0f));

    const half3 curved = half3(
        highPassToneCurve(straightColor.r, inputMidpoint, outputMidpoint),
        highPassToneCurve(straightColor.g, inputMidpoint, outputMidpoint),
        highPassToneCurve(straightColor.b, inputMidpoint, outputMidpoint)
    );
    const half3 smoothed = mix(straightColor, curved, smoothingAmount);
    const half3 detailRestored = mix(smoothed, straightColor, detailProtection);
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();
    const uint2 left = uint2(gid.x > 0 ? gid.x - 1 : gid.x, gid.y);
    const uint2 right = uint2(min(gid.x + 1, width - 1), gid.y);
    const uint2 top = uint2(gid.x, gid.y > 0 ? gid.y - 1 : gid.y);
    const uint2 bottom = uint2(gid.x, min(gid.y + 1, height - 1));
    const half3 neighborAverage = (
        highPassStraightColor(inputTexture, left) +
        highPassStraightColor(inputTexture, right) +
        highPassStraightColor(inputTexture, top) +
        highPassStraightColor(inputTexture, bottom)
    ) * half(0.25);
    const half3 detailBoost = (straightColor - neighborAverage) * sharpness * smoothingAmount;
    const half3 result = clamp(detailRestored + detailBoost, half3(0.0), half3(1.0));
    outputTexture.write(half4(result * source.a, source.a), gid);
}
