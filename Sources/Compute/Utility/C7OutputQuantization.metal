//
//  C7OutputQuantization.metal
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

#include <metal_stdlib>
using namespace metal;

static inline float c7OrderedDither4x4(uint2 position) {
    constexpr float values[16] = {
         0.0f,  8.0f,  2.0f, 10.0f,
        12.0f,  4.0f, 14.0f,  6.0f,
         3.0f, 11.0f,  1.0f,  9.0f,
        15.0f,  7.0f, 13.0f,  5.0f
    };
    const uint index = (position.y & 3u) * 4u + (position.x & 3u);
    return (values[index] + 0.5f) / 16.0f - 0.5f;
}

// 低位坐标先取得较高权重，保持各尺寸矩阵的同一朝向和全局相位。
static inline float c7OrderedDitherRecursive(uint2 position, uint bitCount) {
    constexpr uint digits[4] = {0u, 2u, 3u, 1u};
    uint rank = 0u;
    for (uint bit = 0u; bit < bitCount; ++bit) {
        const uint2 coordinate = (position >> bit) & 1u;
        rank = rank * 4u + digits[coordinate.y * 2u + coordinate.x];
    }
    const uint entries = 1u << (bitCount * 2u);
    return (float(rank) + 0.5f) / float(entries) - 0.5f;
}

static inline float c7InterleavedGradientNoise(float2 position, float seed) {
    const float2 value = position + float2(seed, seed * 0.754877666f);
    return fract(52.9829189f * fract(dot(value, float2(0.06711056f, 0.00583715f)))) - 0.5f;
}

kernel void C7OutputQuantization(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 constant float *bitDepthPointer [[buffer(0)]],
                                 constant float *patternPointer [[buffer(1)]],
                                 constant float *strengthPointer [[buffer(2)]],
                                 constant float *seedPointer [[buffer(3)]],
                                 constant float4 *harbethRegionContext [[buffer(30)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float4 input = float4(inputTexture.read(grid));
    const float bitDepth = clamp(round(*bitDepthPointer), 1.0f, 16.0f);
    const float levels = exp2(bitDepth) - 1.0f;
    const uint pattern = uint(round(*patternPointer));
    const float strength = clamp(*strengthPointer, 0.0f, 1.0f);
    const int2 globalPixel = int2(floor(float2(grid) + harbethRegionContext->xy));
    float noise = 0.0f;
    if (pattern == 1u) {
        noise = c7OrderedDither4x4(uint2(globalPixel));
    } else if (pattern == 2u) {
        noise = c7InterleavedGradientNoise(float2(globalPixel), *seedPointer);
    } else if (pattern == 3u) {
        noise = c7OrderedDitherRecursive(uint2(globalPixel), 1u);
    } else if (pattern == 4u) {
        noise = c7OrderedDitherRecursive(uint2(globalPixel), 3u);
    }

    float4 output = input;
    output.rgb = clamp(floor(clamp(input.rgb, 0.0f, 1.0f) * levels + 0.5f + noise * strength) / levels, 0.0f, 1.0f);
    outputTexture.write(half4(output), grid);
}
