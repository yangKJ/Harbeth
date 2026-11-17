//
//  TextureGeometry.metal
//  Harbeth
//
//  Created by Condy on 2026/11/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void HarbethTextureGeometry(texture2d<float, access::write> output [[texture(0)]],
                                   texture2d<float, access::sample> input [[texture(1)]],
                                   constant float4 &sourceRect [[buffer(0)]],
                                   constant float4 &destinationRect [[buffer(1)]],
                                   constant float2 &flips [[buffer(2)]],
                                   constant float4 &background [[buffer(3)]],
                                   constant float4 &sampleRowX [[buffer(4)]],
                                   constant float4 &sampleRowY [[buffer(5)]],
                                   constant float &halfOutput [[buffer(6)]],
                                   uint2 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()) return;
    float2 uv = (float2(position) + 0.5f) / float2(output.get_width(), output.get_height());
    float2 local = (uv - destinationRect.xy) / destinationRect.zw;
    if (any(local < 0.0f) || any(local > 1.0f)) {
        output.write(halfOutput > 0.5f ? float4(half4(background)) : background, position);
        return;
    }
    local = select(local, 1.0f - local, flips > 0.5f);
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    const float3 point = float3(sourceRect.xy + local * sourceRect.zw, 1.0f);
    const float2 sourceUV = float2(dot(sampleRowX.xyz, point), dot(sampleRowY.xyz, point));
    if (any(sourceUV < 0.0f) || any(sourceUV > 1.0f)) {
        output.write(halfOutput > 0.5f ? float4(half4(background)) : background, position);
        return;
    }
    const float4 value = input.sample(sampling, sourceUV);
    output.write(halfOutput > 0.5f ? float4(half4(value)) : value, position);
}

kernel void HarbethTextureOverlay(texture2d<float, access::write> output [[texture(0)]],
                                  texture2d<float, access::read> input [[texture(1)]],
                                  texture2d<float, access::sample> overlay [[texture(2)]],
                                  constant float4 &rect [[buffer(0)]],
                                  constant float &halfOutput [[buffer(1)]],
                                  uint2 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()) return;
    const float4 base = input.read(position);
    const float2 uv = (float2(position) + 0.5f) / float2(output.get_width(), output.get_height());
    const float2 local = (uv - rect.xy) / rect.zw;
    if (any(local < 0.0f) || any(local > 1.0f)) {
        output.write(halfOutput > 0.5f ? float4(half4(base)) : base, position);
        return;
    }
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    const float4 layer = overlay.sample(sampling, local);
    const float4 result = layer + base * (1.0f - layer.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, position);
}
