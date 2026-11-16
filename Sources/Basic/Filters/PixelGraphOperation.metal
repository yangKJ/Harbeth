//
//  PixelGraphOperation.metal
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//
#include <metal_stdlib>
using namespace metal;

kernel void PixelGraphOperation(texture2d<half, access::write> output [[texture(0)]],
    texture2d<half, access::read> source [[texture(1)]], texture2d<half, access::read> background [[texture(2)]],
    texture2d<half, access::read> mask [[texture(3)]], constant int &operation [[buffer(0)]],
    constant float4 &r [[buffer(1)]], constant float4 &g [[buffer(2)]], constant float4 &b [[buffer(3)]],
    constant float4 &a [[buffer(4)]], constant float4 &bias [[buffer(5)]], constant float4 &maximum [[buffer(6)]],
    uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    // 数值覆盖直接乘入完整预乘 RGBA，无需透明底图或中间覆盖表面。
    if (operation == 10) {
        output.write(half4(float4(source.read(p)) * clamp(float(mask.read(p).r), 0.0f, 1.0f)), p);
        return;
    }
    float4 s = float4(source.read(p)), d = float4(background.read(p)), m = float4(mask.read(p));
    float4 value = s;
    if (operation == 9) value = bias;
    else if (operation == 0) {
        // Color matrices operate on straight samples, then restore premultiplication.
        float4 straight = s.a > 0 ? float4(s.rgb / s.a, s.a) : float4(0);
        float4 v = float4(dot(straight, r), dot(straight, g), dot(straight, b), dot(straight, a)) + bias;
        value = float4(v.rgb * v.a, v.a);
    } else if (operation == 1) value = clamp(s, bias, maximum);
    else if (operation == 2 || operation == 3) value = mix(d, s, clamp(operation == 2 ? m.r : m.a, 0.0f, 1.0f));
    else if (operation == 4) value = s * d;
    else if (operation == 5) value = s.a > 0 ? float4(s.rgb / s.a, s.a) : float4(0);
    else if (operation == 6) value.a = 1;
    else if (operation == 7) value = mix(d, s, clamp(m.r, 0.0f, 1.0f));
    else if (operation == 8) value = float4(s.a > 0 ? s.rgb * d.a / s.a : d.rgb, d.a);
    output.write(half4(value), p);
}

kernel void ImageRegionTransform(texture2d<half, access::write> output [[texture(0)]],
    texture2d<half, access::sample> source [[texture(1)]], constant float4 &src [[buffer(0)]],
    constant float4 &dst [[buffer(1)]], constant float4 &r0 [[buffer(2)]], constant float4 &r1 [[buffer(3)]],
    constant float4 &r2 [[buffer(4)]], constant bool &clamped [[buffer(5)]], uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    float2 uv = (float2(p) + .5) / float2(output.get_width(), output.get_height());
    float3 position = float3(dst.x + uv.x * dst.z, dst.y + (1 - uv.y) * dst.w, 1);
    float z = dot(r2.xyz, position);
    float2 q = float2(dot(r0.xyz, position), dot(r1.xyz, position)) / z;
    float2 sampleUV = float2((q.x - src.x) / src.z, 1 - (q.y - src.y) / src.w);
    constexpr sampler transparent(coord::normalized, address::clamp_to_zero, filter::linear);
    constexpr sampler edge(coord::normalized, address::clamp_to_edge, filter::linear);
    output.write(abs(z) > 1e-8 ? (clamped ? source.sample(edge, sampleUV) : source.sample(transparent, sampleUV)) : half4(0), p);
}

// 核心采样位置和滤波尺度只由全局逆映射决定，裁片尺寸不参与缩小相位。
static float regionLanczosWeight(float x) {
    x = abs(x);
    if (x < 1e-5f) return 1;
    if (x >= 3) return 0;
    float p = M_PI_F * x;
    return sin(p) * sin(p / 3) / (p * p / 3);
}

kernel void ImageRegionLanczosTransform(texture2d<half, access::write> output [[texture(0)]],
    texture2d<half, access::read> source [[texture(1)]], constant float4 &src [[buffer(0)]],
    constant float4 &dst [[buffer(1)]], constant float4 &r0 [[buffer(2)]], constant float4 &r1 [[buffer(3)]],
    constant float4 &r2 [[buffer(4)]], constant bool &clamped [[buffer(5)]], uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    float2 step = dst.zw / float2(output.get_width(), output.get_height());
    float3 position = float3(dst.x + (p.x + .5f) * step.x, dst.y + dst.w - (p.y + .5f) * step.y, 1);
    float z = dot(r2.xyz, position);
    if (abs(z) < 1e-8f) { output.write(half4(0), p); return; }
    float2 q = float2(dot(r0.xyz, position), dot(r1.xyz, position)) / z;
    float2 dx = (float2(r0.x, r1.x) - q * r2.x) / z * step.x;
    float2 dy = (float2(r0.y, r1.y) - q * r2.y) / z * step.y;
    float2 footprint = max(float2(1), float2(length(float2(dx.x, dy.x)), length(float2(dx.y, dy.y))));
    float2 radius = 3 * footprint;
    int2 first = int2(ceil(q - radius - .5f));
    int2 last = int2(floor(q + radius - .5f));
    float4 sum = 0;
    float total = 0;
    int2 size = int2(source.get_width(), source.get_height());
    for (int y = first.y; y <= last.y; ++y) {
        float wy = regionLanczosWeight((y + .5f - q.y) / footprint.y);
        for (int x = first.x; x <= last.x; ++x) {
            float weight = wy * regionLanczosWeight((x + .5f - q.x) / footprint.x);
            int2 index = int2(x - int(src.x), int(src.y + src.w) - 1 - y);
            if (clamped || all(index >= 0) && all(index < size)) {
                sum += float4(source.read(uint2(clamp(index, int2(0), size - 1)))) * weight;
            }
            total += weight;
        }
    }
    // 预乘域统一滤波；只约束 alpha，不裁掉 HDR 的超白颜色。
    float4 value = abs(total) > 1e-8f ? sum / total : float4(0);
    value.a = clamp(value.a, 0.0f, 1.0f);
    if (value.a == 0) value.rgb = 0;
    output.write(half4(value), p);
}
