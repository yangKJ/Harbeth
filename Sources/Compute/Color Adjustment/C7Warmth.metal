//
//  C7Warmth.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Warmth(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::read> inputTexture [[texture(1)]],
                   constant float *warmth [[buffer(0)]],
                   uint2 grid [[thread_position_in_grid]]) {
    
    const half4 inColor = inputTexture.read(grid);
    float warmthValue = *warmth;
    
    half4 outColor = inColor;
    
    if (warmthValue > 0.0) {
        // 暖色调：增加红色和绿色，减少蓝色
        outColor.r += half(warmthValue * 0.3);
        outColor.g += half(warmthValue * 0.2);
        outColor.b -= half(warmthValue * 0.2);
    } else if (warmthValue < 0.0) {
        // 冷色调：减少红色和绿色，增加蓝色
        float absWarmth = abs(warmthValue);
        outColor.r -= half(absWarmth * 0.2);
        outColor.g -= half(absWarmth * 0.1);
        outColor.b += half(absWarmth * 0.3);
    }
    
    // 确保颜色值在有效范围内
    outColor.r = clamp(outColor.r, half(0.0), half(1.0));
    outColor.g = clamp(outColor.g, half(0.0), half(1.0));
    outColor.b = clamp(outColor.b, half(0.0), half(1.0));
    outColor.a = inColor.a;
    
    outputTexture.write(outColor, grid);
}
