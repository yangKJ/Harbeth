//
//  Pixellated.metal
//  MetalDemo
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void Pixellated(texture2d<half, access::write> outTexture [[texture(0)]],
                       texture2d<half, access::sample> inTexture [[texture(1)]],
                       constant float *pixelWidth [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const float2 sampleDivisor = float2(float(*pixelWidth), float(*pixelWidth) * float(inTexture.get_width()) / float(inTexture.get_height()));
    const float2 textureCoordinate = float2(float(grid.x) / outTexture.get_width(), float(grid.y) / outTexture.get_height());
    const float2 xxx = textureCoordinate - sampleDivisor * floor(textureCoordinate / sampleDivisor);
    const float2 samplePos = textureCoordinate - xxx + float2(0.5) * sampleDivisor;
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inTexture.sample(quadSampler, samplePos);
    outTexture.write(outColor, grid);
}
