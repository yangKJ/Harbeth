//
//  C7LocalTone.metal
//  Harbeth
//
//  Created by Condy on 2026/10/30.
//

#include <metal_stdlib>
using namespace metal;

static bool localToneSDR(float3 color) { return all(isfinite(color)) && all(color >= 0.0f) && all(color <= 1.0f); }

kernel void localToneAccumulate(texture2d<half, access::read> source [[texture(0)]],
    device atomic_uint *histogram [[buffer(0)]], device atomic_uint *counts [[buffer(1)]],
    constant uint *values [[buffer(2)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= source.get_width() || gid.y >= source.get_height()) return;
    uint2 size = uint2(values[0], values[1]);
    uint2 global = gid + uint2(values[2], values[3]);
    float4 pixel = float4(source.read(gid));
    if (pixel.a <= 0.0f) return;
    float3 color = pixel.rgb / pixel.a;
    if (!localToneSDR(color)) return;
    uint column = min(global.x * values[4] / size.x, values[4] - 1u);
    uint row = min(global.y * values[5] / size.y, values[5] - 1u);
    uint tile = row * values[4] + column;
    uint bin = min(uint(dot(color, float3(0.299f, 0.587f, 0.114f)) * 255.0f + 0.5f), 255u);
    atomic_fetch_add_explicit(&histogram[tile * 256u + bin], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&counts[tile], 1u, memory_order_relaxed);
}

kernel void localTonePercentiles(device const atomic_uint *histogram [[buffer(0)]],
    device const atomic_uint *counts [[buffer(1)]], device float *percentiles [[buffer(2)]],
    constant uint &columns [[buffer(3)]], constant uint &rows [[buffer(4)]], uint tile [[thread_position_in_grid]]) {
    if (tile >= columns * rows) return;
    uint count = atomic_load_explicit(&counts[tile], memory_order_relaxed);
    if (count == 0u) {
        for (uint j = 0; j < 3; ++j) percentiles[tile * 3u + j] = 0.5f;
        return;
    }
    uint targets[3] = {max(1u, count / 10u), max(1u, count / 2u), count - count / 10u};
    uint cumulative = 0u, found = 0u;
    for (uint bin = 0; bin < 256u && found < 3u; ++bin) {
        cumulative += atomic_load_explicit(&histogram[tile * 256u + bin], memory_order_relaxed);
        while (found < 3u && cumulative >= targets[found]) {
            percentiles[tile * 3u + found] = float(bin) / 255.0f;
            ++found;
        }
    }
}

static float2 localToneMapping(uint tile, float luminance, device const float *lookup,
    device const float *percentiles, float amount, bool classic) {
    float p10 = percentiles[tile * 3u], median = percentiles[tile * 3u + 1u], p90 = percentiles[tile * 3u + 2u];
    if (!classic && p90 - p10 < 0.5f / 255.0f) return float2(luminance, 0.0f);
    if (amount >= 0.0f) {
        uint bin = min(uint(luminance * 255.0f + 0.5f), 255u);
        return float2(mix(luminance, lookup[tile * 256u + bin], amount), 0.0f);
    }
    float edgeProtection = 1.0f - smoothstep(0.6f, 1.6f, abs(luminance - median) / max(p90 - p10, 0.02f));
    float compression = -amount * 0.65f * edgeProtection;
    return float2(mix(luminance, median, compression), compression);
}

kernel void localToneApply(texture2d<half, access::write> destination [[texture(0)]],
    texture2d<half, access::read> source [[texture(1)]], device const float *lookup [[buffer(0)]],
    device const float *percentiles [[buffer(1)]], constant uint *values [[buffer(2)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= destination.get_width() || gid.y >= destination.get_height()) return;
    half4 original = source.read(gid);
    float4 pixel = float4(original);
    float amount = as_type<float>(values[6]);
    float3 color = pixel.a > 0.0f ? pixel.rgb / pixel.a : float3(0.0f);
    if (amount == 0.0f || pixel.a <= 0.0f || !localToneSDR(color)) {
        destination.write(original, gid);
        return;
    }
    uint2 global = gid + uint2(values[2], values[3]);
    uint columns = values[4], rows = values[5];
    float2 grid = clamp((float2(global) + 0.5f) * float2(columns, rows) / float2(values[0], values[1]) - 0.5f, float2(0.0f), float2(columns - 1u, rows - 1u));
    uint2 a = uint2(floor(grid)), b = min(a + 1u, uint2(columns - 1u, rows - 1u));
    float2 fraction = fract(grid);
    float luminance = dot(color, float3(0.299f, 0.587f, 0.114f));
    float2 tl = localToneMapping(a.y * columns + a.x, luminance, lookup, percentiles, amount, values[7] != 0u);
    float2 tr = localToneMapping(a.y * columns + b.x, luminance, lookup, percentiles, amount, values[7] != 0u);
    float2 bl = localToneMapping(b.y * columns + a.x, luminance, lookup, percentiles, amount, values[7] != 0u);
    float2 br = localToneMapping(b.y * columns + b.x, luminance, lookup, percentiles, amount, values[7] != 0u);
    float2 mapped = mix(mix(tl, tr, fraction.x), mix(bl, br, fraction.x), fraction.y);
    if (values[7] != 0u) {
        float3 result = luminance > 1.0e-6f ? clamp(color * (mapped.x / luminance), 0.0f, 1.0f) : color;
        destination.write(half4(half3(result * pixel.a), original.a), gid);
        return;
    }
    float target = clamp(mapped.x, 0.0f, 1.0f);
    float3 candidate = luminance > 1.0e-7f ? color * (target / luminance) : float3(target);
    float3 chroma = (candidate - target) * (1.0f - mapped.y * 0.12f);
    float scale = 1.0f;
    for (uint channel = 0; channel < 3; ++channel) {
        if (chroma[channel] > 0.0f) scale = min(scale, (1.0f - target) / chroma[channel]);
        if (chroma[channel] < 0.0f) scale = min(scale, -target / chroma[channel]);
    }
    destination.write(half4(half3((target + chroma * clamp(scale, 0.0f, 1.0f)) * pixel.a), original.a), gid);
}
