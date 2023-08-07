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
                          constant float *few [[buffer(0)]],
                          uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float x = float(grid.x) / outputTexture.get_width();
    float y = float(grid.y) / outputTexture.get_height();
    
    if (*few == 2.0) { // 两屏
        y = (y >= 0.0 && y <= 0.5) ? y + 0.25 : y - 0.25;
    } else if (*few == 3.0) {
        if (y < 1.0 / 3.0) {
            y += 1.0 / 3.0;
        } else if (y > 2.0 / 3.0) {
            y -= 1.0 / 3.0;
        }
    }
    
    const half4 outColor = inputTexture.sample(quadSampler, float2(x, y));
    outputTexture.write(outColor, grid);
}
