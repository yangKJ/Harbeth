//
//  TextureGeometry.metal
//  Harbeth
//
//  Created by Condy on 2026/11/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void HarbethTextureGeometry(texture2d<half, access::write> output [[texture(0)]],
                                   texture2d<half, access::sample> input [[texture(1)]],
                                   constant float4 &sourceRect [[buffer(0)]],
                                   constant float4 &destinationRect [[buffer(1)]],
                                   constant float2 &flips [[buffer(2)]],
                                   constant float4 &background [[buffer(3)]],
                                   constant float4 &sampleRowX [[buffer(4)]],
                                   constant float4 &sampleRowY [[buffer(5)]],
                                   uint2 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()) return;
    float2 uv = (float2(position) + 0.5f) / float2(output.get_width(), output.get_height());
    float2 local = (uv - destinationRect.xy) / destinationRect.zw;
    if (any(local < 0.0f) || any(local > 1.0f)) {
        output.write(half4(background), position);
        return;
    }
    local = select(local, 1.0f - local, flips > 0.5f);
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    const float3 point = float3(sourceRect.xy + local * sourceRect.zw, 1.0f);
    const float2 sourceUV = float2(dot(sampleRowX.xyz, point), dot(sampleRowY.xyz, point));
    if (any(sourceUV < 0.0f) || any(sourceUV > 1.0f)) {
        output.write(half4(background), position);
        return;
    }
    output.write(input.sample(sampling, sourceUV), position);
}

kernel void HarbethTextureOverlay(texture2d<half, access::write> output [[texture(0)]],
                                  texture2d<half, access::read> input [[texture(1)]],
                                  texture2d<half, access::sample> overlay [[texture(2)]],
                                  constant float4 &rect [[buffer(0)]],
                                  uint2 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()) return;
    const half4 base = input.read(position);
    const float2 uv = (float2(position) + 0.5f) / float2(output.get_width(), output.get_height());
    const float2 local = (uv - rect.xy) / rect.zw;
    if (any(local < 0.0f) || any(local > 1.0f)) {
        output.write(base, position);
        return;
    }
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    const half4 layer = overlay.sample(sampling, local);
    output.write(layer + base * (1.0h - layer.a), position);
}
