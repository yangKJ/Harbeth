//
//  C7Sharpen.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Sharpen(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::sample> inputTexture [[texture(1)]],
                      constant float *sharpeness [[buffer(0)]],
                      uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    const float2 leftCoordinate = float2((x - 1) / width, y / height);
    const float2 rightCoordinate = float2((x + 1) / width, y / height);
    const float2 topCoordinate = float2(x / width, (y - 1) / height);
    const float2 bottomCoordinate = float2(x / width, (y + 1) / height);
    
    const half4 leftColor = inputTexture.sample(quadSampler, leftCoordinate);
    const half4 rightColor = inputTexture.sample(quadSampler, rightCoordinate);
    const half4 topColor = inputTexture.sample(quadSampler, topCoordinate);
    const half4 bottomColor = inputTexture.sample(quadSampler, bottomCoordinate);
    
    const half centerMultiplier = 1.0h + 4.0h * half(*sharpeness);
    const half edgeMultiplier = half(*sharpeness);
    const half3 rgb = (inColor.rgb * centerMultiplier - (leftColor.rgb + rightColor.rgb + topColor.rgb + bottomColor.rgb) * edgeMultiplier);
    const half4 outColor = half4(rgb, bottomColor.a);
    
    outputTexture.write(outColor, grid);
}
