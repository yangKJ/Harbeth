//
//  C7Crop.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Crop(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::sample> inputTexture [[texture(1)]],
                   constant float *originX [[buffer(0)]],
                   constant float *originY [[buffer(1)]],
                   uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float minX = inputTexture.get_width()  * (*originX);
    const float minY = inputTexture.get_height() * (*originY);
    const half4 outColor = inputTexture.sample(quadSampler, float2((grid.x + minX) / inputTexture.get_width(), (grid.y + minY) / inputTexture.get_height()));
    
    outputTexture.write(outColor, grid);
}
