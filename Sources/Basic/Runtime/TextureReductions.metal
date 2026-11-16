//
//  TextureReductions.metal
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//

#include <metal_stdlib>
using namespace metal;

static bool reductionFinite(float value) {
    return (as_type<uint>(value) & 0x7f800000u) != 0x7f800000u;
}

static void addHistogramWeight(threadgroup atomic_uint *value, float weight) {
    uint old = atomic_load_explicit(value, memory_order_relaxed);
    while (!atomic_compare_exchange_weak_explicit(
        value, &old, as_type<uint>(as_type<float>(old) + weight), memory_order_relaxed, memory_order_relaxed
    )) {}
}

template <bool UseSIMD>
static void weightedHistogramBlocks(
    texture2d<float, access::read> source,
    texture2d<float, access::read> coverage,
    device float *results,
    constant uint *p,
    uint2 group,
    uint lane,
    threadgroup atomic_uint *bins
) {
    for (uint i = lane; i < 768; i += 256) atomic_store_explicit(&bins[i], 0u, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    const uint blocksY = (p[3] + 31) / 32;
    device atomic_uint *invalid = reinterpret_cast<device atomic_uint *>(results + p[4] * blocksY * 768);
    for (uint local = lane; local < 1024; local += 256) {
        const uint2 relative = group * 32 + uint2(local % 32, local / 32);
        if (relative.x >= p[2] || relative.y >= p[3]) continue;
        const uint2 point = uint2(p[0], p[1]) + relative;
        const float4 color = source.read(point);
        if (!reductionFinite(color.a)) {
            atomic_store_explicit(invalid, 1u, memory_order_relaxed);
            continue;
        }
        if (color.a <= 0.0f) continue;
        const float clip = p[5] == 0 ? 1.0f : coverage.read(point).r;
        if (!reductionFinite(clip)) {
            atomic_store_explicit(invalid, 1u, memory_order_relaxed);
            continue;
        }
        const float weight = min(1.0f, color.a) * clamp(clip, 0.0f, 1.0f);
        if (weight <= 0.0f) continue;
        const float3 rgb = color.rgb / color.a;
        for (uint channel = 0; channel < 3; channel++) {
            if (!reductionFinite(rgb[channel])) {
                atomic_store_explicit(invalid, 1u, memory_order_relaxed);
                continue;
            }
            const uint bin = uint(floor(clamp(rgb[channel], 0.0f, 1.0f) * 255.0f + 0.5f));
            // Merge uniform active SIMD lanes before the atomic update. Flat regions otherwise
            // serialize hundreds of floating-point CAS retries against the same three bins.
            if constexpr (UseSIMD) {
                const uint firstBin = simd_broadcast_first(bin);
                if (simd_all(bin == firstBin)) {
                    const float combinedWeight = simd_sum(weight);
                    if (simd_is_first()) addHistogramWeight(&bins[channel * 256 + bin], combinedWeight);
                } else {
                    addHistogramWeight(&bins[channel * 256 + bin], weight);
                }
            } else {
                addHistogramWeight(&bins[channel * 256 + bin], weight);
            }
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    const uint offset = (group.y * p[4] + group.x) * 768;
    for (uint i = lane; i < 768; i += 256) {
        results[offset + i] = as_type<float>(atomic_load_explicit(&bins[i], memory_order_relaxed));
    }
}

kernel void WeightedColorHistogramBlocks(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> coverage [[texture(1)]],
    device float *results [[buffer(0)]],
    constant uint *p [[buffer(1)]],
    uint2 group [[threadgroup_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]]
) {
    threadgroup atomic_uint bins[768];
    weightedHistogramBlocks<false>(source, coverage, results, p, group, lane, bins);
}

kernel void WeightedColorHistogramSIMDBlocks(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> coverage [[texture(1)]],
    device float *results [[buffer(0)]],
    constant uint *p [[buffer(1)]],
    uint2 group [[threadgroup_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]]
) {
    threadgroup atomic_uint bins[768];
    weightedHistogramBlocks<true>(source, coverage, results, p, group, lane, bins);
}

kernel void TextureAlphaBoundsBlocks(
    texture2d<float, access::read> source [[texture(0)]],
    device atomic_uint *results [[buffer(0)]],
    constant uint *p [[buffer(1)]],
    uint2 group [[threadgroup_position_in_grid]]
) {
    uint left = p[0], top = p[1], right = 0, bottom = 0, active = 0, invalid = 0;
    for (uint y = group.y * 16; y < min((group.y + 1) * 16, p[1]); y++) {
        for (uint x = group.x * 16; x < min((group.x + 1) * 16, p[0]); x++) {
            const float alpha = source.read(uint2(x, y)).a;
            const uint bits = as_type<uint>(alpha);
            if (!reductionFinite(alpha)) { invalid = 1; continue; }
            if ((bits & 0x80000000u) == 0 && (bits & 0x7fffffffu) != 0) {
                left = min(left, x); top = min(top, y);
                right = max(right, x); bottom = max(bottom, y); active = 1;
            }
        }
    }
    if (active != 0) {
        atomic_fetch_min_explicit(&results[0], left, memory_order_relaxed);
        atomic_fetch_min_explicit(&results[1], top, memory_order_relaxed);
        atomic_fetch_max_explicit(&results[2], right, memory_order_relaxed);
        atomic_fetch_max_explicit(&results[3], bottom, memory_order_relaxed);
        atomic_store_explicit(&results[4], 1u, memory_order_relaxed);
    }
    if (invalid != 0) atomic_store_explicit(&results[5], 1u, memory_order_relaxed);
}

// 按 bin 归并条带，补偿求和降低大图累加误差。
kernel void WeightedColorHistogramFinalize(device const float *partials [[buffer(0)]],
                                          device float *result [[buffer(1)]],
                                          constant uint &count [[buffer(2)]],
                                          uint bin [[thread_position_in_grid]]) {
    if (bin >= 768) return;
    float sum = 0.0f, correction = 0.0f;
    for (uint block = 0; block < count; ++block) {
        float value = partials[block * 768 + bin] - correction;
        float next = sum + value;
        correction = (next - sum) - value;
        sum = next;
    }
    result[bin] += sum;
    if (bin == 0 && as_type<uint>(partials[count * 768]) != 0) result[768] = as_type<float>(1u);
}
