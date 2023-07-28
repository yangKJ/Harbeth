//
//  C7ZoomBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ZoomBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::sample> inputTexture [[texture(1)]],
                       constant float *blurCenterX [[buffer(0)]],
                       constant float *blurCenterY [[buffer(1)]],
                       constant float *radius [[buffer(2)]],
                       uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float2 blurCenter = float2(*blurCenterX, *blurCenterY);
    const float2 textureCoord = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 offset = 1.0 / 100.0 * (blurCenter - textureCoord) * float(*radius);
    
    half4 outColor = inputTexture.sample(quadSampler, textureCoord) * 0.18;
    
    outColor += inputTexture.sample(quadSampler, textureCoord + (1.0 * offset)) * 0.15h;
    outColor += inputTexture.sample(quadSampler, textureCoord + (2.0 * offset)) * 0.12h;
    outColor += inputTexture.sample(quadSampler, textureCoord + (3.0 * offset)) * 0.09h;
    outColor += inputTexture.sample(quadSampler, textureCoord + (4.0 * offset)) * 0.05h;
    outColor += inputTexture.sample(quadSampler, textureCoord - (1.0 * offset)) * 0.15h;
    outColor += inputTexture.sample(quadSampler, textureCoord - (2.0 * offset)) * 0.12h;
    outColor += inputTexture.sample(quadSampler, textureCoord - (3.0 * offset)) * 0.09h;
    outColor += inputTexture.sample(quadSampler, textureCoord - (4.0 * offset)) * 0.05h;
    
    outputTexture.write(outColor, grid);
}
