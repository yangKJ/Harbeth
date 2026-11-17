//
//  C7MaskedForegroundBlend.metal
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7MaskedForegroundBlend(texture2d<float, access::write> outputTexture [[texture(0)]],
                                    texture2d<float, access::read> backgroundTexture [[texture(1)]],
                                    texture2d<float, access::sample> foregroundTexture [[texture(2)]],
                                    texture2d<float, access::sample> maskTexture [[texture(3)]],
                                    constant float *intensity [[buffer(0)]],
                                    constant float &halfOutput [[buffer(1)]],
                                    uint2 grid [[thread_position_in_grid]]) {
    if(grid.x>=outputTexture.get_width() || grid.y>=outputTexture.get_height()) return;
    const float4 background = backgroundTexture.read(grid);
    if(!isfinite(*intensity) || *intensity<=0.0f) {outputTexture.write(background,grid);return;}
    if(background.a<=0.0f) {outputTexture.write(float4(0),grid);return;}
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);

    float width = float(outputTexture.get_width());
    float height = float(outputTexture.get_height());
    float2 uv = float2((float(grid.x)+0.5f) / width, (float(grid.y)+0.5f) / height);

    const float4 foreground = foregroundTexture.sample(quadSampler, uv);
    const float4 mask = maskTexture.sample(quadSampler, uv);

    const float blendAmount = clamp(mask.r * float(*intensity), float(0.0), float(1.0));
    const float3 blendedRGB = mix(background.rgb, foreground.rgb, blendAmount);
    const float4 output(blendedRGB, background.a);

    outputTexture.write(halfOutput>0.5f ? float4(half4(output)):output, grid);
}
