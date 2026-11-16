//
//  C7ChromaticAberrationCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

static float4 sampleOpticsColor(texture2d<float, access::sample> inputTexture,
                                float2 uv,
                                int sampleMode,
                                int edgeMode) {
    constexpr sampler nearestTransparent(coord::normalized, address::clamp_to_zero, filter::nearest);
    constexpr sampler linearTransparent(coord::normalized, address::clamp_to_zero, filter::linear);
    constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);
    constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
    constexpr sampler nearestRepeat(coord::normalized, address::repeat, filter::nearest);
    constexpr sampler linearRepeat(coord::normalized, address::repeat, filter::linear);
    constexpr sampler nearestMirror(coord::normalized, address::mirrored_repeat, filter::nearest);
    constexpr sampler linearMirror(coord::normalized, address::mirrored_repeat, filter::linear);
#if defined(__HAVE_BICUBIC_FILTERING__)
    constexpr sampler bicubicTransparent(coord::normalized, address::clamp_to_zero, filter::bicubic);
    constexpr sampler bicubicClamp(coord::normalized, address::clamp_to_edge, filter::bicubic);
    constexpr sampler bicubicRepeat(coord::normalized, address::repeat, filter::bicubic);
    constexpr sampler bicubicMirror(coord::normalized, address::mirrored_repeat, filter::bicubic);
#endif

    const bool useNearest = sampleMode == 0;
#if defined(__HAVE_BICUBIC_FILTERING__)
    const bool preferBicubic = sampleMode == 2;
#else
    const bool preferBicubic = false;
#endif

    float4 color;
    if (useNearest) {
        switch (edgeMode) {
            case 1: color = inputTexture.sample(nearestClamp, uv); break;
            case 2: color = inputTexture.sample(nearestRepeat, uv); break;
            case 3: color = inputTexture.sample(nearestMirror, uv); break;
            default: color = inputTexture.sample(nearestTransparent, uv); break;
        }
    } else if (preferBicubic) {
#if defined(__HAVE_BICUBIC_FILTERING__)
        switch (edgeMode) {
            case 1: color = inputTexture.sample(bicubicClamp, uv); break;
            case 2: color = inputTexture.sample(bicubicRepeat, uv); break;
            case 3: color = inputTexture.sample(bicubicMirror, uv); break;
            default: color = inputTexture.sample(bicubicTransparent, uv); break;
        }
#else
        switch (edgeMode) {
            case 1: color = inputTexture.sample(linearClamp, uv); break;
            case 2: color = inputTexture.sample(linearRepeat, uv); break;
            case 3: color = inputTexture.sample(linearMirror, uv); break;
            default: color = inputTexture.sample(linearTransparent, uv); break;
        }
#endif
    } else {
        switch (edgeMode) {
            case 1: color = inputTexture.sample(linearClamp, uv); break;
            case 2: color = inputTexture.sample(linearRepeat, uv); break;
            case 3: color = inputTexture.sample(linearMirror, uv); break;
            default: color = inputTexture.sample(linearTransparent, uv); break;
        }
    }

    return float4(color);
}

// 透明边缘的覆盖衰减与对象自身 alpha 分开处理，保持不透明图片的原边界视觉。
static float channelObjectAlpha(texture2d<float, access::sample> input, float2 uv,
                                float sampledAlpha, int mode, int edgeMode) {
    if (sampledAlpha <= 0 || edgeMode != 0) return sampledAlpha;
#if defined(__HAVE_BICUBIC_FILTERING__)
    float radius = mode == 0 ? 0 : (mode == 2 ? 2 : 0.5f);
#else
    float radius = mode == 0 ? 0 : 0.5f;
#endif
    float2 margin = radius / float2(input.get_width(), input.get_height());
    if (any(uv < margin) || any(uv > 1.0f - margin)) {
        return sampleOpticsColor(input, uv, mode, 1).a;
    }
    return sampledAlpha;
}

kernel void C7ChromaticAberrationCorrection(texture2d<float, access::write> outputTexture [[texture(0)]],
                                            texture2d<float, access::sample> inputTexture [[texture(1)]],
                                            constant float2 &center [[buffer(0)]],
                                            constant float2 &channelShifts [[buffer(1)]],
                                            constant int &samplingMode [[buffer(2)]],
                                            constant int &edgeMode [[buffer(3)]],
                                            uint2 grid [[thread_position_in_grid]]) {

    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float2 uv = float2(
        (float(grid.x) + 0.5f) / float(outputTexture.get_width()),
        (float(grid.y) + 0.5f) / float(outputTexture.get_height())
    );
    const float2 textureSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float maxDimension = max(textureSize.x, textureSize.y);

    float2 offset = uv - center;
    float2 radial = offset * textureSize / maxDimension;
    float radius2 = dot(radial, radial);
    float2 direction = radius2 > 0.000001f ? normalize(radial) : float2(0.0f);
    float2 shiftBase = direction * radius2 * maxDimension / textureSize;

    const int sampleMode = samplingMode;
    const int borderMode = edgeMode;

    float4 base = sampleOpticsColor(inputTexture, uv, sampleMode, borderMode);
    if (base.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
    float2 redUV = uv + shiftBase * channelShifts.x;
    float2 blueUV = uv + shiftBase * channelShifts.y;
    float4 redShifted = sampleOpticsColor(inputTexture, redUV, sampleMode, borderMode);
    float4 blueShifted = sampleOpticsColor(inputTexture, blueUV, sampleMode, borderMode);
    float redAlpha = channelObjectAlpha(inputTexture, redUV, redShifted.a, sampleMode, borderMode);
    float blueAlpha = channelObjectAlpha(inputTexture, blueUV, blueShifted.a, sampleMode, borderMode);
    float4 outputColor = base;
    outputColor.r = channelShifts.x == 0 ? base.r : (redAlpha > 0 ? redShifted.r / redAlpha * base.a : 0);
    outputColor.b = channelShifts.y == 0 ? base.b : (blueAlpha > 0 ? blueShifted.b / blueAlpha * base.a : 0);
    outputTexture.write(float4(outputColor), grid);
}
