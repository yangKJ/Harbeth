//
//  C7Bulge.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Bulge(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::sample> inputTexture [[texture(1)]],
                    constant float *centerPointerX [[buffer(0)]],
                    constant float *centerPointerY [[buffer(1)]],
                    constant float *radiusPointer [[buffer(2)]],
                    constant float *scalePointer [[buffer(3)]],
                    uint2 grid [[thread_position_in_grid]]) {
    const float2 center = float2(*centerPointerX, *centerPointerY);
    const float radius = float(*radiusPointer);
    const float scale = float(*scalePointer);
    const float aspectRatio = float(inputTexture.get_height()) / float(inputTexture.get_width());
    
    const float2 inCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    float2 textureCoordinate = float2(inCoordinate.x, (inCoordinate.y - center.y) * aspectRatio + center.y);
    const float dist = distance(center, textureCoordinate);
    textureCoordinate = inCoordinate;
    
    if (dist < radius) {
        textureCoordinate -= center;
        float percent = 1.0 - (radius - dist) / radius * scale;
        percent = percent * percent;
        textureCoordinate = textureCoordinate * percent + center;
    }
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inputTexture.sample(quadSampler, textureCoordinate);
    outputTexture.write(outColor, grid);
}
