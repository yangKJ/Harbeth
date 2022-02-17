//
//  C7RGBADilation.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7RGBADilation(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::sample> inputTexture [[texture(1)]],
                           constant float *pixelRadius [[buffer(0)]],
                           constant float *vertical [[buffer(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    half4 maxValue = half4(0.0h);
    
    const int radius = abs(*pixelRadius);
    if (*vertical) {
        for (int i = -radius; i <= radius; ++i) {
            const float2 coordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y + i) / outputTexture.get_height());
            const half4 intensity = inputTexture.sample(quadSampler, coordinate);
            maxValue = max(maxValue, intensity);
        }
    } else {
        for (int i = -radius; i <= radius; ++i) {
            const float2 coordinate = float2(float(grid.x + i) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
            const half4 intensity = inputTexture.sample(quadSampler, coordinate);
            maxValue = max(maxValue, intensity);
        }
    }
    
    outputTexture.write(maxValue, grid);
}
