//
//  C7Deband.metal
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

#include <metal_stdlib>
using namespace metal;

static inline float4 debandOutputColor(float4 value, float halfOutput) {
    return halfOutput > 0.5f ? float4(half4(value)) : value;
}

static inline float c7DebandLuminance(float3 color) {
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

static inline float c7DebandNoise(uint2 grid) {
    const float seed = dot(float2(grid), float2(12.9898f, 78.233f));
    return fract(sin(seed) * 43758.5453f) - 0.5f;
}

// 仅在 GPU 证明当前线程组及其完整 halo 都不透明后使用等价简化。
static inline float4 debandOpaqueColor(texture2d<float, access::read> inputTexture,
                                       uint2 grid,
                                       uint2 extent,
                                       int radius,
                                       float3 settings) {
    const uint width = extent.x, height = extent.y;
    const float threshold = settings.x, amount = settings.y, dither = settings.z;
    const float4 center = float4(inputTexture.read(grid));
    const float centerLuma = c7DebandLuminance(center.rgb);

    float4 accumulated = center;
    float weightSum = 1.0f;
    float localContrast = 0.0f;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            if (x == 0 && y == 0) {
                continue;
            }

            const int sampleX = clamp(int(grid.x) + x, 0, int(width) - 1);
            const int sampleY = clamp(int(grid.y) + y, 0, int(height) - 1);
            const float4 sample = float4(inputTexture.read(uint2(sampleX, sampleY)));
            const float lumaDelta = fabs(c7DebandLuminance(sample.rgb) - centerLuma);
            localContrast = max(localContrast, lumaDelta);

            const float spatialDistance = length(float2(x, y));
            const float spatialWeight = max(0.0f, 1.0f - spatialDistance / float(radius + 1));
            const float similarity = 1.0f - smoothstep(threshold * 0.35f, max(threshold, 1e-5f), lumaDelta);
            const float weight = spatialWeight * similarity;

            accumulated += sample * weight;
            weightSum += weight;
        }
    }

    float4 smoothed = accumulated / max(weightSum, 1e-5f);
    smoothed.a = center.a;

    const float flatRegion = 1.0f - smoothstep(threshold, threshold * 2.5f + 1e-5f, localContrast);
    float4 output = mix(center, smoothed, amount * flatRegion);
    const float noise = c7DebandNoise(grid) * dither * amount * flatRegion / 255.0f;
    output.rgb = clamp(output.rgb + noise, 0.0f, 1.0f);
    output.a = center.a;

    return output;
}

kernel void C7Deband(texture2d<float, access::write> outputTexture [[texture(0)]],
                     texture2d<float, access::read> inputTexture [[texture(1)]],
                     constant float *radiusPointer [[buffer(0)]],
                     constant float *thresholdPointer [[buffer(1)]],
                     constant float *amountPointer [[buffer(2)]],
                     constant float *ditherPointer [[buffer(3)]],
                     constant float &halfOutput [[buffer(4)]],
                     uint2 grid [[thread_position_in_grid]],
                     uint2 local [[thread_position_in_threadgroup]],
                     uint2 groupSize [[threads_per_threadgroup]]) {
    const uint width = outputTexture.get_width();
    const uint height = outputTexture.get_height();
    const bool inside = grid.x < width && grid.y < height;
    float4 center = float4(0.0f);
    if (inside) center = inputTexture.read(grid);
    const float amount = clamp(*amountPointer, 0.0f, 1.0f);
    if (amount <= 0.0f) {
        if (inside) outputTexture.write(debandOutputColor(center.a > 0.0f ? float4(clamp(center.rgb, 0.0f, center.a), center.a) : float4(0.0f), halfOutput), grid);
        return;
    }
    const int radius = max(int(round(*radiusPointer)), 1);
    const float threshold = max(*thresholdPointer, 0.0f);
    const float dither = clamp(*ditherPointer, 0.0f, 1.0f);
    // 非零强度的所有线程先完成协作；越界线程也必须参与屏障。
    threadgroup atomic_uint nonOpaque;
    // 颜色探针只决定是否值得检查；实际准入以整个 halo 的 alpha 为准。
    const int2 maximum = int2(width - 1, height - 1);
    const int2 probeOrigin = int2(grid) - int2(local);
    float4 first = float4(0), second = float4(0);
    if (width >= 512 && height >= 512) {
        first = inputTexture.read(uint2(clamp(probeOrigin, int2(0), maximum)));
        second = inputTexture.read(uint2(clamp(probeOrigin + int2(groupSize / 2), int2(0), maximum)));
    }
    if (width >= 512 && height >= 512 && first.a == 1.0f && all(first == second)) {
        const uint lane = local.y * groupSize.x + local.x;
        if (lane == 0) atomic_store_explicit(&nonOpaque, 0u, memory_order_relaxed);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        const uint tileWidth = groupSize.x + uint(2 * radius);
        const uint tileHeight = groupSize.y + uint(2 * radius);
        const int2 origin = int2(grid) - int2(local);
        for (uint i = lane; i < tileWidth * tileHeight; i += groupSize.x * groupSize.y) {
            const int2 position = origin + int2(int(i % tileWidth) - radius, int(i / tileWidth) - radius);
            const uint2 coordinate = uint2(clamp(position, int2(0), int2(width - 1, height - 1)));
            if (inputTexture.read(coordinate).a != 1.0f) {
                atomic_store_explicit(&nonOpaque, 1u, memory_order_relaxed);
                break;
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (atomic_load_explicit(&nonOpaque, memory_order_relaxed) == 0u) {
            if (inside) outputTexture.write(debandOutputColor(debandOpaqueColor(inputTexture, grid, uint2(width, height), radius, float3(threshold, amount, dither)), halfOutput), grid);
            return;
        }
    }
    if (!inside) return;
    if (center.a <= 0.0f) { outputTexture.write(float4(0.0f), grid); return; }
    const float3 centerColor = center.rgb / center.a;
    const float centerLuma = c7DebandLuminance(centerColor);
    float3 accumulated = center.rgb;
    float coverageSum = center.a;
    float localContrast = 0.0f;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            if (x == 0 && y == 0) continue;
            const int sampleX = clamp(int(grid.x) + x, 0, int(width) - 1);
            const int sampleY = clamp(int(grid.y) + y, 0, int(height) - 1);
            const float4 sample = inputTexture.read(uint2(sampleX, sampleY));
            if (sample.a <= 0.0f) continue;
            const float lumaDelta = fabs(c7DebandLuminance(sample.rgb / sample.a) - centerLuma);
            localContrast = max(localContrast, lumaDelta);
            // 平坦区权重已归零，后续邻居不会再影响颜色或 dither。
            if (localContrast >= threshold * 2.5f + 1e-5f) {
                outputTexture.write(debandOutputColor(float4(clamp(center.rgb, 0.0f, center.a), center.a), halfOutput), grid);
                return;
            }
            const float spatialDistance = length(float2(x, y));
            const float spatialWeight = max(0.0f, 1.0f - spatialDistance / float(radius + 1));
            const float similarity = 1.0f - smoothstep(threshold * 0.35f, max(threshold, 1e-5f), lumaDelta);
            const float weight = spatialWeight * similarity;
            // 颜色按有效覆盖率归一化，透明邻居不引入黑边或改变中心 alpha。
            accumulated += sample.rgb * weight;
            coverageSum += sample.a * weight;
        }
    }

    const float3 smoothed = accumulated / coverageSum;
    const float flatRegion = 1.0f - smoothstep(threshold, threshold * 2.5f + 1e-5f, localContrast);
    const float3 color = mix(centerColor, smoothed, amount * flatRegion);
    const float noise = c7DebandNoise(grid) * dither * amount * flatRegion / 255.0f;
    outputTexture.write(debandOutputColor(float4(clamp(color + noise, 0.0f, 1.0f) * center.a, center.a), halfOutput), grid);
}
