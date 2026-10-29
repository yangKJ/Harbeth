//
//  C7LocalLaplacian.metal
//  Harbeth
//
//  Created by Condy on 2026/10/30.
//

#include <metal_stdlib>
using namespace metal;

static float2 lapRead(texture2d<float, access::read> texture, int2 point, uint4 domain) {
    int2 full = clamp(point, int2(0), int2(domain.zw) - 1);
    int2 local = full - int2(domain.xy);
    local = clamp(local, int2(0), int2(texture.get_width(), texture.get_height()) - 1);
    return texture.read(uint2(local)).rg;
}

static float lapExpand(texture2d<float, access::read> texture, uint2 point, uint4 domain) {
    float2 p = float2(point) * 0.5f;
    int2 q = int2(floor(p));
    float2 t = fract(p);
    float2 a = lapRead(texture, q, domain);
    float2 b = lapRead(texture, q + int2(1, 0), domain);
    float2 c = lapRead(texture, q + int2(0, 1), domain);
    float2 d = lapRead(texture, q + int2(1, 1), domain);
    float weight = mix(mix(a.y, b.y, t.x), mix(c.y, d.y, t.x), t.y);
    float value = mix(mix(a.x * a.y, b.x * b.y, t.x), mix(c.x * c.y, d.x * d.y, t.x), t.y);
    return weight > 0.0f ? value / weight : 0.0f;
}

kernel void localLaplacianStage(
    texture2d<float, access::write> output [[texture(0)]],
    texture2d<float, access::read> input [[texture(1)]],
    texture2d<float, access::read> coarse [[texture(2)]],
    texture2d<float, access::read> guide [[texture(3)]],
    texture2d<float, access::read> sum [[texture(4)]],
    constant uint4 *domains [[buffer(0)]],
    constant float4 &values [[buffer(1)]],
    constant float &intensity [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    uint operation = domains[0].x;
    uint2 point = gid + domains[0].yz;
    float4 result = float4(0.0f);
    if (operation == 0u) {
        float4 source = input.read(point - domains[1].xy);
        float3 color = source.a > 0.0f ? source.rgb / source.a : float3(0.0f);
        bool valid = source.a > 0.0f && all(isfinite(color)) && all(color >= 0.0f) && all(color <= 1.0f);
        result = float4(valid ? dot(color, float3(0.299f, 0.587f, 0.114f)) : 0.0f, valid ? source.a : 0.0f, 0.0f, 1.0f);
    } else if (operation == 1u) {
        float2 base = lapRead(input, int2(point), domains[1]);
        float difference = base.x - values.z;
        float detail = difference * exp(-0.5f * difference * difference / (values.y * values.y));
        result = float4(base.x + values.x * detail, base.y, 0.0f, 1.0f);
    } else if (operation == 2u) {
        const float weights[5] = {1.0f, 4.0f, 6.0f, 4.0f, 1.0f};
        float total = 0.0f, coverage = 0.0f;
        for (int y = -2; y <= 2; ++y) {
            for (int x = -2; x <= 2; ++x) {
                float2 sample = lapRead(input, int2(point) * 2 + int2(x, y), domains[1]);
                float weight = weights[x + 2] * weights[y + 2] / 256.0f;
                total += sample.x * sample.y * weight;
                coverage += sample.y * weight;
            }
        }
        result = float4(coverage > 0.0f ? total / coverage : 0.0f, coverage, 0.0f, 1.0f);
    } else if (operation == 3u) {
        result = float4(0.0f, lapRead(input, int2(point), domains[1]).y, 0.0f, 1.0f);
    } else if (operation == 4u) {
        float2 original = guide.read(point - domains[3].xy).rg;
        float prior = sum.read(point - domains[3].zw).r;
        float weight = max(0.0f, 1.0f - abs(original.x - values.z) / values.w);
        float residual = lapRead(input, int2(point), domains[1]).x - lapExpand(coarse, point, domains[2]);
        result = float4(prior + weight * residual, original.y, 0.0f, 1.0f);
    } else if (operation == 5u) {
        float2 residual = lapRead(input, int2(point), domains[1]);
        result = float4(residual.x + lapExpand(coarse, point, domains[2]), residual.y, 0.0f, 1.0f);
    } else {
        float4 source = input.read(point - domains[1].xy);
        float3 color = source.a > 0.0f ? source.rgb / source.a : float3(0.0f);
        if (source.a <= 0.0f || !all(isfinite(color)) || any(color < 0.0f) || any(color > 1.0f)) {
            output.write(source, gid);
            return;
        }
        float luminance = dot(color, float3(0.299f, 0.587f, 0.114f));
        float target = clamp(coarse.read(point - domains[2].xy).r, 0.0f, 1.0f);
        // 向目标灰度压缩超出色域的色度，避免逐通道截断改变色相。
        float3 candidate = luminance > 1.0e-7f ? color * (target / luminance) : float3(target);
        float3 chroma = candidate - target;
        float scale = 1.0f;
        for (uint c = 0; c < 3; ++c) {
            if (chroma[c] > 0.0f) scale = min(scale, (1.0f - target) / chroma[c]);
            if (chroma[c] < 0.0f) scale = min(scale, -target / chroma[c]);
        }
        candidate = target + chroma * clamp(scale, 0.0f, 1.0f);
        result = float4(mix(source.rgb, candidate * source.a, intensity), source.a);
    }
    output.write(result, gid);
}
