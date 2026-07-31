//
//  C7ChromaticAberrationCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

static float4 sampleOpticsColor(texture2d<half, access::sample> inputTexture,
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

    half4 color;
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

kernel void C7ChromaticAberrationCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                                            texture2d<half, access::sample> inputTexture [[texture(1)]],
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
    float4 redShifted = sampleOpticsColor(inputTexture, uv + shiftBase * channelShifts.x, sampleMode, borderMode);
    float4 blueShifted = sampleOpticsColor(inputTexture, uv + shiftBase * channelShifts.y, sampleMode, borderMode);

    float4 outputColor = base;
    outputColor.r = redShifted.r;
    outputColor.b = blueShifted.b;
    outputTexture.write(half4(outputColor), grid);
}
