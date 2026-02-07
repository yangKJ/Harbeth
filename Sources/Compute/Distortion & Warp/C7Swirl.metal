//
//  C7Swirl.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Swirl(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::sample> inputTexture [[texture(1)]],
                    constant float *centerPointerX [[buffer(0)]],
                    constant float *centerPointerY [[buffer(1)]],
                    constant float *radiusPointer [[buffer(2)]],
                    constant float *anglePointer [[buffer(3)]],
                    uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float2 center = float2(*centerPointerX, *centerPointerY);
    const float radius = float(*radiusPointer);
    const float angle = float(*anglePointer);
    
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float dist = distance(center, textureCoordinate);
    
    if (dist < radius) {
        textureCoordinate -= center;
        const float percent = (radius - dist) / radius;
        const float theta = percent * percent * angle * 8.0;
        const float s = sin(theta);
        const float c = cos(theta);
        textureCoordinate = float2(dot(textureCoordinate, float2(c, -s)), dot(textureCoordinate, float2(s, c)));
        textureCoordinate += center;
    }
    
    const half4 outColor = inputTexture.sample(quadSampler, textureCoordinate);
    outputTexture.write(outColor, grid);
}
