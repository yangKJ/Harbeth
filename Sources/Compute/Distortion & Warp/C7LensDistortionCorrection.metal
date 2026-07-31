//
//  C7LensDistortionCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LensDistortionCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                                       texture2d<half, access::sample> inputTexture [[texture(1)]],
                                       constant float2 &center [[buffer(0)]],
                                       constant float2 &distortionCoefficients [[buffer(1)]],
                                       constant float &scale [[buffer(2)]],
                                       constant int &samplingMode [[buffer(3)]],
                                       constant int &edgeMode [[buffer(4)]],
                                       uint2 grid [[thread_position_in_grid]]) {

    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

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

    const float2 uv = float2(
        (float(grid.x) + 0.5f) / float(outputTexture.get_width()),
        (float(grid.y) + 0.5f) / float(outputTexture.get_height())
    );

    const float2 textureSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float maxDimension = max(textureSize.x, textureSize.y);

    float2 offset = uv - center;
    float2 radial = offset * textureSize / maxDimension;
    float r2 = dot(radial, radial);
    float radialFactor = 1.0f + distortionCoefficients.x * r2 + distortionCoefficients.y * r2 * r2;
    radial *= radialFactor * scale;
    float2 correctedUV = center + radial * maxDimension / textureSize;

    const int sampleMode = samplingMode;
    const int borderMode = edgeMode;
    const bool useNearest = sampleMode == 0;
#if defined(__HAVE_BICUBIC_FILTERING__)
    const bool preferBicubic = sampleMode == 2;
#else
    const bool preferBicubic = false;
#endif

    half4 color;
    if (useNearest) {
        switch (borderMode) {
            case 1: color = inputTexture.sample(nearestClamp, correctedUV); break;
            case 2: color = inputTexture.sample(nearestRepeat, correctedUV); break;
            case 3: color = inputTexture.sample(nearestMirror, correctedUV); break;
            default: color = inputTexture.sample(nearestTransparent, correctedUV); break;
        }
    } else if (preferBicubic) {
#if defined(__HAVE_BICUBIC_FILTERING__)
        switch (borderMode) {
            case 1: color = inputTexture.sample(bicubicClamp, correctedUV); break;
            case 2: color = inputTexture.sample(bicubicRepeat, correctedUV); break;
            case 3: color = inputTexture.sample(bicubicMirror, correctedUV); break;
            default: color = inputTexture.sample(bicubicTransparent, correctedUV); break;
        }
#else
        switch (borderMode) {
            case 1: color = inputTexture.sample(linearClamp, correctedUV); break;
            case 2: color = inputTexture.sample(linearRepeat, correctedUV); break;
            case 3: color = inputTexture.sample(linearMirror, correctedUV); break;
            default: color = inputTexture.sample(linearTransparent, correctedUV); break;
        }
#endif
    } else {
        switch (borderMode) {
            case 1: color = inputTexture.sample(linearClamp, correctedUV); break;
            case 2: color = inputTexture.sample(linearRepeat, correctedUV); break;
            case 3: color = inputTexture.sample(linearMirror, correctedUV); break;
            default: color = inputTexture.sample(linearTransparent, correctedUV); break;
        }
    }

    outputTexture.write(color, grid);
}
