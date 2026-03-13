//
//  C7Clarity.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

// 高斯模糊函数
float4 clarityGaussianBlur(texture2d<half, access::read> texture, uint2 position, float blurRadius, uint2 size) {
    float4 color = float4(0.0);
    float totalWeight = 0.0;
    
    // 计算高斯核大小
    int kernelSize = int(ceil(blurRadius * 10.0));
    
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            // 计算高斯权重
            float distance = sqrt(float(x * x + y * y));
            float weight = exp(-(distance * distance) / (2.0 * blurRadius * blurRadius));
            
            // 计算采样位置
            uint2 samplePos = position + uint2(x, y);
            
            // 边界检查
            if (samplePos.x < size.x && samplePos.y < size.y) {
                color += float4(texture.read(samplePos)) * weight;
                totalWeight += weight;
            }
        }
    }
    
    return color / totalWeight;
}

kernel void C7Clarity(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::read> inputTexture [[texture(1)]],
                   constant float *intensity [[buffer(0)]],
                   constant float *radius [[buffer(1)]],
                   uint2 grid [[thread_position_in_grid]]) {
    
    const uint2 textureSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    const float4 inColor = float4(inputTexture.read(grid));
    
    float clarityIntensity = *intensity;
    float blurRadius = *radius;
    
    if (clarityIntensity == 0.0) {
        outputTexture.write(half4(inColor), grid);
        return;
    }
    
    // 应用高斯模糊
    float4 blurredColor = clarityGaussianBlur(inputTexture, grid, blurRadius * 10.0, textureSize);
    
    // 计算边缘细节（原始图像 - 模糊图像）
    float4 detail = inColor - blurredColor;
    
    // 增强细节并加回原始图像
    float4 outColor = inColor + detail * clarityIntensity;
    
    // 确保颜色值在有效范围内
    outColor.r = clamp(outColor.r, 0.0, 1.0);
    outColor.g = clamp(outColor.g, 0.0, 1.0);
    outColor.b = clamp(outColor.b, 0.0, 1.0);
    outColor.a = inColor.a;
    
    outputTexture.write(half4(outColor), grid);
}
