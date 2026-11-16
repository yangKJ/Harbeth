//
//  TextureStructureStatistics.metal
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//
#include <metal_stdlib>
using namespace metal;

struct TextureStructurePartial {
    float laplacian;
    float gradient;
    uint sampleCount;
    uint invalid;
};

static float luminance(float3 color) {
    return fma(color.r, 0.2126f, fma(color.g, 0.7152f, color.b * 0.0722f));
}

// 返回 0 表示无有效覆盖，1 表示有效邻域，2 表示数值非法。
static uint readNeighborhood(texture2d<float, access::read> source, uint2 q, uint alphaType,
                             float threshold, thread float *luma) {
    uint index = 0;
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            float4 value = source.read(uint2(int(q.x) + x, int(q.y) + y));
            float alpha = alphaType == 2 ? 1.0f : value.a;
            if (!isfinite(alpha) || alpha < 0.0f || alpha > 1.0f) return 2;
            if (alpha <= 0.0f || alpha < threshold) return 0;
            if (!all(isfinite(value.rgb))) return 2;
            float3 color = alphaType == 0 ? value.rgb / alpha : value.rgb;
            if (!all(isfinite(color))) return 2;
            luma[index++] = luminance(color);
        }
    }
    return 1;
}

kernel void TextureStructureStatisticsBlocks(
    texture2d<float, access::read> source [[texture(0)]],
    device TextureStructurePartial *output [[buffer(0)]],
    constant uint4 &parameters [[buffer(1)]],
    constant float &alphaThreshold [[buffer(2)]],
    uint group [[threadgroup_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]]) {
    threadgroup TextureStructurePartial values[256];
    TextureStructurePartial value = {0, 0, 0, 0};
    uint width = parameters.x, height = parameters.y;
    uint index = group * 256 + lane;
    if (index < width * height) {
        uint2 q = uint2(index % width, index / width);
        if (q.x > 0 && q.y > 0 && q.x + 1 < width && q.y + 1 < height) {
            float colors[9];
            uint state = readNeighborhood(source, q, parameters.z, alphaThreshold, colors);
            if (state == 2) value.invalid = 1;
            if (state == 1) {
                float lap = (colors[4] - colors[1]) + (colors[4] - colors[3]) + (colors[4] - colors[5]) + (colors[4] - colors[7]);
                float gx = (colors[2] - colors[0] + 2.0f * (colors[5] - colors[3]) + colors[8] - colors[6]) / 8.0f;
                float gy = (colors[6] - colors[0] + 2.0f * (colors[7] - colors[1]) + colors[8] - colors[2]) / 8.0f;
                float laplacian = lap * lap;
                float gradient = gx * gx + gy * gy;
                if (isfinite(laplacian) && isfinite(gradient)) {
                    value.laplacian = laplacian;
                    value.gradient = gradient;
                    value.sampleCount = 1;
                } else value.invalid = 1;
            }
        }
    }
    values[lane] = value;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint step = 128; step > 0; step >>= 1) {
        if (lane < step) {
            values[lane].laplacian += values[lane + step].laplacian;
            values[lane].gradient += values[lane + step].gradient;
            values[lane].sampleCount += values[lane + step].sampleCount;
            values[lane].invalid |= values[lane + step].invalid;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) output[group] = values[0];
}

kernel void TextureStructureStatisticsReduce(
    device const TextureStructurePartial *input [[buffer(0)]],
    device TextureStructurePartial *output [[buffer(1)]],
    constant uint &count [[buffer(2)]],
    uint group [[threadgroup_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]]) {
    threadgroup TextureStructurePartial values[256];
    uint index = group * 256 + lane;
    values[lane] = index < count ? input[index] : TextureStructurePartial{0, 0, 0, 0};
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint step = 128; step > 0; step >>= 1) {
        if (lane < step) {
            values[lane].laplacian += values[lane + step].laplacian;
            values[lane].gradient += values[lane + step].gradient;
            values[lane].sampleCount += values[lane + step].sampleCount;
            values[lane].invalid |= values[lane + step].invalid;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) output[group] = values[0];
}
