//
//  C7Resize.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Resize(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::sample> inputTexture [[texture(1)]],
                     uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 outColor = inputTexture.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    
    outputTexture.write(outColor, grid);
}
