//
//  C7BlendWithMask.metal
//  Harbeth
//
//  Created by Condy on 2026/2/8.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendWithMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> backgroundTexture [[texture(1)]],
                            texture2d<half, access::sample> foregroundTexture [[texture(2)]],
                            texture2d<half, access::sample> maskTexture [[texture(3)]],
                            constant float *intensity [[buffer(0)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 background = backgroundTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    float width = float(outputTexture.get_width());
    float height = float(outputTexture.get_height());
    float2 uv = float2(float(grid.x) / width, float(grid.y) / height);
    
    const half4 foreground = foregroundTexture.sample(quadSampler, uv);
    const half4 mask = maskTexture.sample(quadSampler, uv);
    
    half4 blended = mix(background, foreground, mask.r);
    
    const half4 output = mix(background, blended, half(*intensity));
    outputTexture.write(output, grid);
}
