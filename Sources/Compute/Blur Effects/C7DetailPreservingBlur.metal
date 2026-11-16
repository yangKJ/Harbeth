//
//  C7DetailPreservingBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7DetailPreservingBlurPacked(texture2d<float, access::write> outputTexture [[texture(0)]],
                                   texture2d<float, access::sample> inputTexture [[texture(1)]],
                                   constant float &strength [[buffer(0)]],
                                   constant float &detailPreservation [[buffer(1)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    float s = strength, d = detailPreservation;
    float4 centerColor = float4(inputTexture.read(grid));
    if (!isfinite(s) || !isfinite(d) || s == 0.0f) { outputTexture.write(centerColor, grid); return; }
    constexpr sampler linearClamp(coord::pixel, address::clamp_to_edge, filter::linear);
    const float offsets[3] = {-1.2f, 0.0f, 1.2f};
    const float weights[3] = {5.0f / 16.0f, 6.0f / 16.0f, 5.0f / 16.0f};
    float4 blurredColor = float4(0.0f);
    
    for (uint y = 0; y < 3; ++y) {
        for (uint x = 0; x < 3; ++x) {
            float2 coordinate = float2(grid) + 0.5f + float2(offsets[x], offsets[y]);
            blurredColor += inputTexture.sample(linearClamp, coordinate) * weights[x] * weights[y];
        }
    }
    
    float4 highFrequencyDetail = centerColor - blurredColor;
    float4 detailPreserved = blurredColor + highFrequencyDetail * d;
    float4 finalColor = mix(centerColor, detailPreserved, s);
    
    outputTexture.write(finalColor, grid);
}

// 不支持 32-bit 浮点过滤的设备使用整数读取；同样修正边界并以 Float 累加。
kernel void C7DetailPreservingBlur(texture2d<float, access::write> out [[texture(0)]],
    texture2d<float, access::read> source [[texture(1)]], constant float &strength [[buffer(0)]], constant float &detailPreservation [[buffer(1)]],
    uint2 q [[thread_position_in_grid]]) {
    if (q.x >= out.get_width() || q.y >= out.get_height()) return;
    float4 center = source.read(q);
    if (!isfinite(strength) || !isfinite(detailPreservation) || strength == 0) { out.write(center, q); return; }
    const float weights[5] = {1, 4, 6, 4, 1};
    int2 extent = int2(source.get_width(), source.get_height());
    float4 blur = 0;
    for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {
        blur += source.read(uint2(clamp(int2(q) + int2(x,y), int2(0), extent - 1))) * (weights[x+2] * weights[y+2] / 256.0f);
    }
    float4 finalColor = mix(center, blur + (center - blur) * detailPreservation, strength);

    out.write(finalColor, q);
}
