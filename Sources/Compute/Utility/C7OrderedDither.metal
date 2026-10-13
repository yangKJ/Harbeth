//
//  C7OrderedDither.metal
//  Harbeth
//
//  Created by Condy on 2026/10/14.
//

#include <metal_stdlib>
using namespace metal;

static inline float orderedCellNoise(int2 cell, uint pattern, float seed) {
    if (pattern == 0u) { return 0.0f; }
    if (pattern == 2u) {
        const float2 position = float2(cell) + float2(seed, seed * 0.754877666f);
        return fract(52.9829189f * fract(dot(position, float2(0.06711056f, 0.00583715f)))) - 0.5f;
    }
    const uint bitCount = pattern == 3u ? 1u : (pattern == 4u ? 3u : 2u);
    constexpr uint digits[4] = {0u, 2u, 3u, 1u};
    uint rank = 0u;
    for (uint bit = 0u; bit < bitCount; ++bit) {
        const uint2 position = (uint2(cell) >> bit) & 1u;
        rank = rank * 4u + digits[position.y * 2u + position.x];
    }
    return (float(rank) + 0.5f) / float(1u << (bitCount * 2u)) - 0.5f;
}

kernel void C7OrderedDither(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *levelsPointer [[buffer(0)]],
                            constant float *pixelSizePointer [[buffer(1)]],
                            constant float *patternPointer [[buffer(2)]],
                            constant float *strengthPointer [[buffer(3)]],
                            constant float *seedPointer [[buffer(4)]],
                            constant float4 *harbethRegionContext [[buffer(30)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const int2 inputSize = int2(inputTexture.get_width(), inputTexture.get_height());
    if (any(grid >= uint2(inputSize))) { return; }
    const int size = int(clamp(round(*pixelSizePointer), 1.0f, 32.0f));
    const int2 origin = int2(floor(harbethRegionContext->xy));
    const int2 logicalSize = int2(max(harbethRegionContext->zw, float2(1.0f)));
    const int2 cell = int2(floor(float2(int2(grid) + origin) / float(size)));
    const int2 globalStart = cell * size;
    const int2 localStart = max(globalStart - origin, int2(0));
    const int2 localEnd = min(globalStart + size - origin, inputSize);

    // 边界单元由与当前纹理交集的左上角唯一负责，所有写入范围互不重叠。
    if (any(int2(grid) != localStart)) { return; }
    const int2 sampleStart = max(globalStart, int2(0));
    const int2 sampleEnd = min(globalStart + size, logicalSize);
    float3 sum = float3(0.0f);
    float alpha = 0.0f;
    for (int y = sampleStart.y; y < sampleEnd.y; ++y) {
        for (int x = sampleStart.x; x < sampleEnd.x; ++x) {
            const int2 position = int2(x, y) - origin;
            if (any(position < 0) || any(position >= inputSize)) { continue; }
            const float4 value = float4(inputTexture.read(uint2(position)));
            if (value.a > 0.0f) {
                sum += value.rgb;
                alpha += value.a;
            }
        }
    }
    // 全透明单元回落为零色值；中间 Half 舍入与既有直色值量化链一致。
    const float3 color = float3(half3(alpha > 0.0001f ? sum / alpha : float3(0.0f)));
    const float levels = clamp(round(*levelsPointer), 2.0f, 256.0f) - 1.0f;
    const float noise = orderedCellNoise(cell, uint(round(*patternPointer)), *seedPointer);
    const float strength = clamp(*strengthPointer, 0.0f, 1.0f);
    const half3 quantized = half3(clamp(floor(clamp(color, 0.0f, 1.0f) * levels + 0.5f + noise * strength) / levels, 0.0f, 1.0f));
    for (int y = localStart.y; y < localEnd.y; ++y) {
        for (int x = localStart.x; x < localEnd.x; ++x) {
            const uint2 position = uint2(x, y);
            const half sourceAlpha = inputTexture.read(position).a;
            outputTexture.write(half4(quantized * sourceAlpha, sourceAlpha), position);
        }
    }
}
