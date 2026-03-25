//
//  C7ColorBurnEnhancedBlend.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorBurnEnhancedBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                     texture2d<half, access::sample> blendTexture [[texture(2)]],
                                     constant float *intensity [[buffer(0)]],
                                     constant float *strength [[buffer(1)]],
                                     uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 blendColor = blendTexture.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    
    half epsilon = 0.0001h;
    half strengthHalf = half(*strength);
    
    outColor.r = 1.0h - min(1.0h, (1.0h - inColor.r) / max(blendColor.r * strengthHalf, epsilon));
    outColor.g = 1.0h - min(1.0h, (1.0h - inColor.g) / max(blendColor.g * strengthHalf, epsilon));
    outColor.b = 1.0h - min(1.0h, (1.0h - inColor.b) / max(blendColor.b * strengthHalf, epsilon));
    outColor.a = inColor.a;
    
    outColor = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(outColor, grid);
}
