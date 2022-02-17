//
//  C7Toon.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Toon(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::sample> inputTexture [[texture(1)]],
                   constant float *threshold [[buffer(0)]],
                   constant float *quantizationLevels [[buffer(1)]],
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
    const float2 topLeftCoordinate = float2((x - 1) / width, (y - 1) / height);
    const float2 topRightCoordinate = float2((x + 1) / width, (y - 1) / height);
    const float2 bottomLeftCoordinate = float2((x - 1) / width, (y + 1) / height);
    const float2 bottomRightCoordinate = float2((x + 1) / width, (y + 1) / height);
    
    const half leftIntensity = inputTexture.sample(quadSampler, leftCoordinate).r;
    const half rightIntensity = inputTexture.sample(quadSampler, rightCoordinate).r;
    const half topIntensity = inputTexture.sample(quadSampler, topCoordinate).r;
    const half bottomIntensity = inputTexture.sample(quadSampler, bottomCoordinate).r;
    const half topLeftIntensity = inputTexture.sample(quadSampler, topLeftCoordinate).r;
    const half topRightIntensity = inputTexture.sample(quadSampler, topRightCoordinate).r;
    const half bottomLeftIntensity = inputTexture.sample(quadSampler, bottomLeftCoordinate).r;
    const half bottomRightIntensity = inputTexture.sample(quadSampler, bottomRightCoordinate).r;
    
    const half h = -topLeftIntensity - 2.0h * topIntensity - topRightIntensity + bottomLeftIntensity + 2.0h * bottomIntensity + bottomRightIntensity;
    const half v = -bottomLeftIntensity - 2.0h * leftIntensity - topLeftIntensity + bottomRightIntensity + 2.0h * rightIntensity + topRightIntensity;
    
    const half mag = length(half2(h, v));
    const half3 posterizedImageColor = floor((inColor.rgb * half3(*quantizationLevels)) + 0.5h) / half3(*quantizationLevels);
    const half thresholdTest = 1.0h - step(half(*threshold), mag);
    
    const half4 outColor = half4(posterizedImageColor * thresholdTest, inColor.a);
    outputTexture.write(outColor, grid);
}
