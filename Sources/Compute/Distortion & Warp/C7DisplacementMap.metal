//
//  C7DisplacementMap.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

static inline half4 c7DisplacementSample(texture2d<half, access::sample> texture,
                                         float2 coordinate,
                                         int samplingMode,
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

    if (samplingMode == 0) {
        switch (edgeMode) {
            case 1: return texture.sample(nearestClamp, coordinate);
            case 2: return texture.sample(nearestRepeat, coordinate);
            case 3: return texture.sample(nearestMirror, coordinate);
            default: return texture.sample(nearestTransparent, coordinate);
        }
    }
#if defined(__HAVE_BICUBIC_FILTERING__)
    if (samplingMode == 2) {
        switch (edgeMode) {
            case 1: return texture.sample(bicubicClamp, coordinate);
            case 2: return texture.sample(bicubicRepeat, coordinate);
            case 3: return texture.sample(bicubicMirror, coordinate);
            default: return texture.sample(bicubicTransparent, coordinate);
        }
    }
#endif
    switch (edgeMode) {
        case 1: return texture.sample(linearClamp, coordinate);
        case 2: return texture.sample(linearRepeat, coordinate);
        case 3: return texture.sample(linearMirror, coordinate);
        default: return texture.sample(linearTransparent, coordinate);
    }
}

kernel void C7DisplacementMap(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::sample> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> displacementTexture [[texture(2)]],
                              texture2d<half, access::sample> confidenceTexture [[texture(3)]],
                              constant float &scale [[buffer(0)]],
                              constant int &unit [[buffer(1)]],
                              constant int &encoding [[buffer(2)]],
                              constant int &samplingMode [[buffer(3)]],
                              constant int &edgeMode [[buffer(4)]],
                              constant bool &usesConfidence [[buffer(5)]],
                              constant float4 *regionContext [[buffer(30)]],
                              uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;

    constexpr sampler auxiliarySampler(coord::normalized, address::clamp_to_edge, filter::linear);
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float2 logicalInputSize = max(inputRegion.zw, float2(1.0f));
    const float2 logicalOutputSize = max(outputRegion.zw, float2(1.0f));
    const float2 globalOutput = float2(grid) + outputRegion.xy + 0.5f;
    const float2 globalUV = globalOutput / logicalOutputSize;

    float2 displacement = float2(displacementTexture.sample(auxiliarySampler, globalUV).rg);
    if (encoding == 1) displacement = displacement * 2.0f - 1.0f;
    const float2 displacementUV = unit == 0
        ? displacement * scale / logicalInputSize
        : displacement * scale;

    const float2 baseGlobalInput = globalUV * logicalInputSize;
    const float2 displacedGlobalInput = baseGlobalInput + displacementUV * logicalInputSize;
    const float2 localTextureSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 baseCoordinate = (baseGlobalInput - inputRegion.xy) / localTextureSize;
    const float2 displacedCoordinate = (displacedGlobalInput - inputRegion.xy) / localTextureSize;

    const half4 original = c7DisplacementSample(inputTexture, baseCoordinate, samplingMode, edgeMode);
    const half4 displaced = c7DisplacementSample(inputTexture, displacedCoordinate, samplingMode, edgeMode);
    const half confidence = usesConfidence
        ? half(clamp(float(confidenceTexture.sample(auxiliarySampler, globalUV).r), 0.0f, 1.0f))
        : 1.0h;
    outputTexture.write(mix(original, displaced, confidence), grid);
}
