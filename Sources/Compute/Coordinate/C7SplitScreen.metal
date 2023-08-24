//
//  C7SplitScreen.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SplitScreen(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::sample> inputTexture [[texture(1)]],
                          constant float *screen [[buffer(0)]],
                          constant float *direction [[buffer(1)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const float x = float(grid.x) / outputTexture.get_width();
    const float y = float(grid.y) / outputTexture.get_height();
    
    float temp = (*direction) ? y : x;
    if (*screen == 2.0) {
        temp += temp < 0.5 ? 0.25 : -0.25;
    } else if (*screen == 3.0) {
        temp += temp < 1.0/3.0 ? 1.0/3.0 : (temp > 2.0/3.0) ? -1.0/3.0 : 0.0;
    }
    const float2 xy = (*direction) ? float2(x, temp) : float2(temp, y);
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inputTexture.sample(quadSampler, xy);
    outputTexture.write(outColor, grid);
}
