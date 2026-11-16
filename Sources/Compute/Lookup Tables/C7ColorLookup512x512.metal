//
//  C7ColorLookup512x512.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorLookup512x512(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 texture2d<half, access::sample> lookupTexture [[texture(2)]],
                                 constant float *intensity [[buffer(0)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler lookupSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    const float3 color = clamp(float3(inColor.rgb), 0.0f, 1.0f);
    const float blue = color.b * 31.0f;
    const int lower = int(floor(blue));
    const int upper = min(lower + 1, 31);
    const float2 local = color.rg * 31.0f + 0.5f;
    // 既有资源按每块 32 像素、每行 16 个蓝切片解释。
    const float2 first = (float2(lower % 16, lower / 16) * 32.0f + local) / 512.0f;
    const float2 second = (float2(upper % 16, upper / 16) * 32.0f + local) / 512.0f;
    const half3 mapped = mix(lookupTexture.sample(lookupSampler, first).rgb,
                            lookupTexture.sample(lookupSampler, second).rgb, half(fract(blue)));
    outputTexture.write(half4(mix(inColor.rgb, mapped, half(*intensity)), inColor.a), grid);
}
