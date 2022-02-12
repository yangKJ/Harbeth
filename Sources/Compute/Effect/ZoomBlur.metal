//
//  ZoomBlur.metal
//  MetalQueenDemo
//
//  Created by Condy on 2022/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void ZoomBlur(texture2d<half, access::write> outTexture [[texture(0)]],
                     texture2d<half, access::sample> inTexture [[texture(1)]],
                     constant float *blurSize [[buffer(0)]],
                     uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    float2 blurCenter = float2(0.5, 0.5);
    const float2 textureCoordinate = float2(float(grid.x) / outTexture.get_width(),
                                            float(grid.y) / outTexture.get_height());
    const float2 samplingOffset = 1.0 / 100.0 * (blurCenter - textureCoordinate) * float(*blurSize);
    
    half4 color = inTexture.sample(quadSampler, textureCoordinate) * 0.18;
    
    color += inTexture.sample(quadSampler, textureCoordinate + (1.0 * samplingOffset)) * 0.15h;
    color += inTexture.sample(quadSampler, textureCoordinate + (2.0 * samplingOffset)) * 0.12h;
    color += inTexture.sample(quadSampler, textureCoordinate + (3.0 * samplingOffset)) * 0.09h;
    color += inTexture.sample(quadSampler, textureCoordinate + (4.0 * samplingOffset)) * 0.05h;
    color += inTexture.sample(quadSampler, textureCoordinate - (1.0 * samplingOffset)) * 0.15h;
    color += inTexture.sample(quadSampler, textureCoordinate - (2.0 * samplingOffset)) * 0.12h;
    color += inTexture.sample(quadSampler, textureCoordinate - (3.0 * samplingOffset)) * 0.09h;
    color += inTexture.sample(quadSampler, textureCoordinate - (4.0 * samplingOffset)) * 0.05h;
    
    outTexture.write(color, grid);
}
