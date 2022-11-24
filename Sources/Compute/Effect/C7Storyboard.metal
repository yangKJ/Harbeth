//
//  C7Storyboard.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

// See：https://www.shadertoy.com/view/7sscDX

#include <metal_stdlib>
using namespace metal;

kernel void C7Storyboard(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::sample> inputTexture [[texture(1)]],
                         constant float *few [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float x = float(grid.x) / outputTexture.get_width();
    const float y = float(grid.y) / outputTexture.get_height();
    const float2 textureCoordinate = float2(x, y);
    const int N = int(*few);
    const float2 uv = fmod(textureCoordinate, 1.0 / N) * N;
    
    const half4 outColor = inputTexture.sample(quadSampler, uv);
    
    outputTexture.write(outColor, grid);
}
