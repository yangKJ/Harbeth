//
//  C7ChannelControl.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ChannelControl(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             constant float *red [[buffer(0)]],
                             constant float *green [[buffer(1)]],
                             constant float *blue [[buffer(2)]],
                             constant float *alpha [[buffer(3)]],
                             constant float *blend [[buffer(4)]],
                             constant float &halfOutput [[buffer(5)]],
                             uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 inColor = inputTexture.read(grid);
    if (*blend <= 0.0f) { outputTexture.write(inColor, grid); return; }
    
    const float redValue = *red;
    const float greenValue = *green;
    const float blueValue = *blue;
    const float alphaValue = *alpha;
    const float blendValue = *blend;
    
    float4 adjustedColor;
    // 预乘颜色与 alpha 同步衰减，保证黑色背景上的透明效果和后续合成一致。
    adjustedColor.r = float(inColor.r) * (redValue + 1.0) * alphaValue;
    adjustedColor.g = float(inColor.g) * (greenValue + 1.0) * alphaValue;
    adjustedColor.b = float(inColor.b) * (blueValue + 1.0) * alphaValue;
    adjustedColor.a = float(inColor.a) * alphaValue;
    
    float4 originalColor = float4(inColor);
    float blendFactor = blendValue;
    float4 finalColor = originalColor * (1.0 - blendFactor) + adjustedColor * blendFactor;
    
    float4 outColor = halfOutput > 0.5f ? float4(half4(finalColor)) : finalColor;
    
    outputTexture.write(outColor, grid);
}
