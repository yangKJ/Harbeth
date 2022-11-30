//
//  C7Fluctuate.metal
//  Harbeth
//
//  Created by Condy on 2022/11/30.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Fluctuate(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::sample> inputTexture [[texture(1)]],
                        device float *extent [[buffer(0)]],
                        device float *amplitude [[buffer(1)]],
                        device float *fluctuate [[buffer(2)]],
                        uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    float2 offset = float2(0, 0);
    offset.x = sin(grid.x * *extent + *fluctuate) * *amplitude;
    offset.y = cos(grid.y * *extent + *fluctuate) * *amplitude;
    
    const float2 tx = textureCoordinate + offset;
    const half4 outColor = inputTexture.sample(quadSampler, tx);
    
    outputTexture.write(outColor, grid);
}
