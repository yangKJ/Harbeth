//
//  C7ZoomBlur.metal
//  MetalQueenDemo
//
//  Created by Condy on 2022/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ZoomBlur(texture2d<half, access::write> outTexture [[texture(0)]],
                       texture2d<half, access::sample> inTexture [[texture(1)]],
                       constant float *blurCenterX [[buffer(0)]],
                       constant float *blurCenterY [[buffer(1)]],
                       constant float *blurSize [[buffer(2)]],
                       uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    float2 blurCenter = float2(*blurCenterX, *blurCenterY);
    const float2 textureCoord = float2(float(grid.x) / outTexture.get_width(),
                                       float(grid.y) / outTexture.get_height());
    const float2 samplingOffset = 1.0 / 100.0 * (blurCenter - textureCoord) * float(*blurSize);
    
    half4 color = inTexture.sample(quadSampler, textureCoord) * 0.18;
    
    color += inTexture.sample(quadSampler, textureCoord + (1.0 * samplingOffset)) * 0.15h;
    color += inTexture.sample(quadSampler, textureCoord + (2.0 * samplingOffset)) * 0.12h;
    color += inTexture.sample(quadSampler, textureCoord + (3.0 * samplingOffset)) * 0.09h;
    color += inTexture.sample(quadSampler, textureCoord + (4.0 * samplingOffset)) * 0.05h;
    color += inTexture.sample(quadSampler, textureCoord - (1.0 * samplingOffset)) * 0.15h;
    color += inTexture.sample(quadSampler, textureCoord - (2.0 * samplingOffset)) * 0.12h;
    color += inTexture.sample(quadSampler, textureCoord - (3.0 * samplingOffset)) * 0.09h;
    color += inTexture.sample(quadSampler, textureCoord - (4.0 * samplingOffset)) * 0.05h;
    
    outTexture.write(color, grid);
}
