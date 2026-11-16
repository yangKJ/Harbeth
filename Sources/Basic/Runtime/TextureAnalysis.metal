// Created by Condy on 2026/11/16.
#include <metal_stdlib>
using namespace metal;

static float4 analysisColor(texture2d<float, access::read> source, uint2 q, constant float *p) {
    float4 c = source.read(q);
    if (p[4] == 1) c = float4(c.rrr, 1);
    if (p[4] == 2) c = float4(c.rg, 0, 1);
    if (p[4] == 3) c = float4(0, 0, 0, c.a);
    return c;
}
static bool analysisRange(float value, constant float *p, uint offset) {
    if (p[offset] == 0) return true;
    value = clamp(value, 0.0f, 1.0f);
    return p[offset + 3] != 0 ? (value >= p[offset + 1] || value <= p[offset + 2])
        : (value >= min(p[offset + 1], p[offset + 2]) && value <= max(p[offset + 1], p[offset + 2]));
}
static float analysisNormalize(float value, float minimum, float maximum) {
    if (isnan(value)) return value;
    if (value <= minimum) return 0.0f;
    if (value >= maximum) return 1.0f;
    float span = maximum - minimum;
    float normalized = isfinite(span)
        ? precise::divide(value - minimum, span)
        : precise::divide(value * 0.5f - minimum * 0.5f, maximum * 0.5f - minimum * 0.5f);
    return clamp(normalized, 0.0f, 1.0f);
}
static bool analysisAccept(float4 c, uint2 q, texture2d<float, access::read> source,
                           texture2d<float, access::read> mask, constant float *p) {
    if (p[5] != 0) {
        uint2 m = min(q * uint2(mask.get_width(), mask.get_height()) / uint2(source.get_width(), source.get_height()),
                      uint2(mask.get_width() - 1, mask.get_height() - 1));
        if (mask.read(m).r < p[6]) return false;
    }
    float lum = fma(c.r, 0.2126f, fma(c.g, 0.7152f, c.b * 0.0722f));
    if (p[7] != 0 && !(lum >= p[8] && lum <= p[9])) return false;
    if (p[10] != 0 || p[14] != 0 || p[18] != 0) {
        float high = max(c.r, max(c.g, c.b)), low = min(c.r, min(c.g, c.b));
        float delta = high - low, light = (high + low) * 0.5f;
        float saturation = delta == 0 ? 0 : delta / max(0.000001f, 1 - abs(2 * light - 1));
        float hue = delta == 0 ? 0 : (high == c.r ? fmod((c.g - c.b) / delta, 6.0f)
                    : (high == c.g ? (c.b - c.r) / delta + 2 : (c.r - c.g) / delta + 4));
        hue *= 60;
        hue = (hue < 0 ? hue + 360 : hue) / 360;
        if (!analysisRange(hue, p, 10) || !analysisRange(saturation, p, 14) || !analysisRange(light, p, 18)) return false;
    }
    return true;
}
struct AnalysisPartial { float4 color; float4 metrics; uint4 counts; };
static AnalysisPartial emptyPartial() {
    AnalysisPartial a; a.color = 0; a.metrics = float4(0, INFINITY, -INFINITY, 0); a.counts = 0; return a;
}
static void analysisReduce(threadgroup AnalysisPartial *v, uint lane) {
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint step = 128; step > 0; step >>= 1) {
        if (lane < step) {
            v[lane].color += v[lane + step].color;
            v[lane].metrics.x += v[lane + step].metrics.x;
            v[lane].metrics.y = min(v[lane].metrics.y, v[lane + step].metrics.y);
            v[lane].metrics.z = max(v[lane].metrics.z, v[lane + step].metrics.z);
            v[lane].counts.x += v[lane + step].counts.x;
            v[lane].counts.y |= v[lane + step].counts.y;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
}
kernel void AnalysisStatisticsBlocks(texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> mask [[texture(1)]], device AnalysisPartial *out [[buffer(0)]],
    constant float *p [[buffer(1)]], uint group [[threadgroup_position_in_grid]], uint lane [[thread_index_in_threadgroup]]) {
    threadgroup AnalysisPartial values[256];
    AnalysisPartial a = emptyPartial();
    uint index = group * 256 + lane, width = uint(p[2]);
    if (index < width * uint(p[3])) {
        uint2 q = uint2(p[0], p[1]) + uint2(index % width, index / width);
        float4 c = analysisColor(source, q, p);
        if (analysisAccept(c, q, source, mask, p)) {
            if (all(isfinite(c))) {
                float lum = fma(c.r, 0.2126f, fma(c.g, 0.7152f, c.b * 0.0722f));
                a.color = c; a.metrics = float4(lum, lum, lum, 0); a.counts.x = 1;
            } else a.counts.y = 1;
        }
    }
    values[lane] = a; analysisReduce(values, lane);
    if (lane == 0) out[group] = values[0];
}
kernel void AnalysisStatisticsReduce(device const AnalysisPartial *input [[buffer(0)]],
    device AnalysisPartial *out [[buffer(1)]], constant uint &count [[buffer(2)]],
    uint group [[threadgroup_position_in_grid]], uint lane [[thread_index_in_threadgroup]]) {
    threadgroup AnalysisPartial values[256];
    uint index = group * 256 + lane;
    values[lane] = index < count ? input[index] : emptyPartial();
    analysisReduce(values, lane);
    if (lane == 0) out[group] = values[0];
}
// 归并完 bin 后复用线程组空间汇总样本数，避免争用单一全局计数器。
template <bool UseSIMD>
static void analysisScopedHistogram(texture2d<float, access::read> source,
    texture2d<float, access::read> mask, device atomic_uint *out, constant float *p,
    uint group, uint lane, uint simdGroup, threadgroup atomic_uint *bins) {
    uint count = uint(p[25]);
    for (uint b = lane; b < count; b += 256) atomic_store_explicit(bins + b, 0, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint index = group * 256 + lane, width = uint(p[2]);
    if (index < width * uint(p[3])) {
        uint2 q = uint2(p[0], p[1]) + uint2(index % width, index / width);
        float4 c = analysisColor(source, q, p);
        if (analysisAccept(c, q, source, mask, p)) {
            float value = p[24] == 0 ? fma(c.r, 0.2126f, fma(c.g, 0.7152f, c.b * 0.0722f)) : c[uint(p[24]) - 1];
            float normalized = analysisNormalize(value, p[22], p[23]);
            if (isfinite(value) && isfinite(normalized)) {
                uint bin = min(uint(floor(normalized * float(count - 1) + 0.5f)), count - 1);
                atomic_fetch_add_explicit(bins + bin, 1, memory_order_relaxed);
            } else atomic_store_explicit(out + count + 1, 1, memory_order_relaxed);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint subtotal = 0;
    for (uint b = lane; b < count; b += 256) {
        uint n = atomic_load_explicit(bins + b, memory_order_relaxed);
        subtotal += n;
        if (n != 0) atomic_fetch_add_explicit(out + b, n, memory_order_relaxed);
    }
    // 所有 bin 已加载并写到全局结果后，才能覆盖线程组 bin 存储。
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (UseSIMD) {
        uint combined = simd_sum(subtotal);
        if (simd_is_first()) atomic_store_explicit(bins + simdGroup, combined, memory_order_relaxed);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (lane == 0) {
            uint total = 0;
            for (uint i = 0; i < 256 / uint(p[26]); ++i) total += atomic_load_explicit(bins + i, memory_order_relaxed);
            atomic_fetch_add_explicit(out + count, total, memory_order_relaxed);
        }
    } else {
        uint active = min(count, 256u);
        if (lane < active) atomic_store_explicit(bins + lane, subtotal, memory_order_relaxed);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        for (uint step = 128; step > 0; step >>= 1) {
            if (lane < step && lane + step < active) {
                uint sum = atomic_load_explicit(bins + lane, memory_order_relaxed)
                    + atomic_load_explicit(bins + lane + step, memory_order_relaxed);
                atomic_store_explicit(bins + lane, sum, memory_order_relaxed);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
        }
        if (lane == 0) atomic_fetch_add_explicit(out + count, atomic_load_explicit(bins, memory_order_relaxed), memory_order_relaxed);
    }
}

kernel void AnalysisScopedHistogram(texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> mask [[texture(1)]], device atomic_uint *out [[buffer(0)]],
    constant float *p [[buffer(1)]], threadgroup atomic_uint *bins [[threadgroup(0)]],
    uint group [[threadgroup_position_in_grid]], uint lane [[thread_index_in_threadgroup]]) {
    analysisScopedHistogram<false>(source, mask, out, p, group, lane, 0, bins);
}

kernel void AnalysisScopedHistogramSIMD(texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> mask [[texture(1)]], device atomic_uint *out [[buffer(0)]],
    constant float *p [[buffer(1)]], threadgroup atomic_uint *bins [[threadgroup(0)]],
    uint group [[threadgroup_position_in_grid]], uint lane [[thread_index_in_threadgroup]],
    uint simdGroup [[simdgroup_index_in_threadgroup]]) {
    analysisScopedHistogram<true>(source, mask, out, p, group, lane, simdGroup, bins);
}

kernel void AnalysisScopeMask(texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> mask [[texture(1)]], texture2d<float, access::write> out [[texture(2)]],
    constant float *p [[buffer(1)]], uint2 q [[thread_position_in_grid]]) {
    if (q.x >= out.get_width() || q.y >= out.get_height()) return;
    bool region = q.x >= uint(p[0]) && q.y >= uint(p[1]) && q.x < uint(p[0] + p[2]) && q.y < uint(p[1] + p[3]);
    float value = region && analysisAccept(analysisColor(source, q, p), q, source, mask, p) ? 1.0f : 0.0f;
    out.write(float4(value, value, value, 1), q);
}

// 预览参数 ABI 与 histogramPreviewKernel 共用：offset / count / height / peak。
kernel void AnalysisHistogramPeak(device const uint *histogram [[buffer(0)]],
    device uint *parameters [[buffer(1)]], uint lane [[thread_index_in_threadgroup]]) {
    threadgroup uint peaks[256];
    uint peak = 0;
    for (uint bin = lane; bin < parameters[1]; bin += 256) peak = max(peak, histogram[parameters[0] + bin]);
    peaks[lane] = peak;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint step = 128; step > 0; step >>= 1) {
        if (lane < step) peaks[lane] = max(peaks[lane], peaks[lane + step]);
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) parameters[3] = peaks[0];
}
