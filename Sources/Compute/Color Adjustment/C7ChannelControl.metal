//
//  C7ChannelControl.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ChannelControl(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *red [[buffer(0)]],
                             constant float *green [[buffer(1)]],
                             constant float *blue [[buffer(2)]],
                             constant float *alpha [[buffer(3)]],
                             constant float *blend [[buffer(4)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    // 解析参数
    const float redValue = *red;
    const float greenValue = *green;
    const float blueValue = *blue;
    const float alphaValue = *alpha;
    const float blendValue = *blend;
    
    // 应用通道控制（0 代表原图）
    float4 adjustedColor;
    adjustedColor.r = float(inColor.r) * (redValue + 1.0); // -1.0~1.0 映射到 0.0~2.0
    adjustedColor.g = float(inColor.g) * (greenValue + 1.0);
    adjustedColor.b = float(inColor.b) * (blueValue + 1.0);
    adjustedColor.a = float(inColor.a) * alphaValue;
    
    // 应用混合强度（0 代表原图）
    float4 originalColor = float4(inColor);
    float blendFactor = (blendValue + 1.0) / 2.0; // -1.0~1.0 映射到 0.0~1.0
    float4 finalColor = originalColor * (1.0 - blendFactor) + adjustedColor * blendFactor;
    
    // 确保值在有效范围内
    half4 outColor;
    outColor.r = half(clamp(finalColor.r, 0.0, 1.0));
    outColor.g = half(clamp(finalColor.g, 0.0, 1.0));
    outColor.b = half(clamp(finalColor.b, 0.0, 1.0));
    outColor.a = half(clamp(finalColor.a, 0.0, 1.0));
    
    outputTexture.write(outColor, grid);
}
