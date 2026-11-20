//
//  C7Clarity.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

// 高斯模糊函数
float4 clarityGaussianBlur(texture2d<float, access::read> texture, uint2 position, float blurRadius, uint2 size) {
    float4 color = float4(0.0);
    float totalWeight = 0.0;
    
    // 计算高斯核大小
    int kernelSize = int(ceil(blurRadius * 10.0));
    
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            // 计算高斯权重
            float distance2 = float(x * x + y * y);
            float weight = distance2 == 0 ? 1.0f : exp(-distance2 / (2.0 * blurRadius * blurRadius));
            
            // 计算采样位置
            int2 samplePos = int2(position) + int2(x, y);
            
            // 边界检查
            if (all(samplePos >= 0) && samplePos.x < int(size.x) && samplePos.y < int(size.y)) {
                color += float4(texture.read(uint2(samplePos))) * weight;
                totalWeight += weight;
            }
        }
    }
    
    return color / totalWeight;
}

kernel void C7Clarity(texture2d<float, access::write> outputTexture [[texture(0)]],
                      texture2d<float, access::read> inputTexture [[texture(1)]],
                      constant float *intensity [[buffer(0)]],
                      constant float *radius [[buffer(1)]],
                      uint2 grid [[thread_position_in_grid]]) {
    
    const uint2 textureSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const uint2 point = min(grid, textureSize - 1);
    const float4 inColor = inputTexture.read(point);
    
    float clarityIntensity = *intensity;
    float blurRadius = *radius;
    
    if (!isfinite(clarityIntensity) || !isfinite(blurRadius) || clarityIntensity == 0.0 || blurRadius <= 0.0) {
        outputTexture.write(inColor, grid);
        return;
    }
    
    // 应用高斯模糊
    float4 blurredColor = clarityGaussianBlur(inputTexture, point, blurRadius * 10.0, textureSize);
    
    // 计算边缘细节（原始图像 - 模糊图像）
    float4 detail = inColor - blurredColor;
    
    // 增强细节并加回原始图像
    float4 outColor = inColor + detail * clarityIntensity;
    
    outColor.a = inColor.a;
    
    outputTexture.write(outColor, grid);
}

// 可分离路径逐轴排除画布外邻居并归一化，保持直接算法的边界定义。
kernel void ClarityHorizontal(texture2d<float, access::read> source [[texture(0)]],
                              texture2d<float, access::write> temporary [[texture(1)]],
                              constant int &radius [[buffer(0)]],
                              constant float *weights [[buffer(1)]],
                              uint2 q [[thread_position_in_grid]]) {
    if (q.x >= source.get_width() || q.y >= source.get_height()) return;
    float4 value = 0;
    float total = 0;
    for (int x = -radius; x <= radius; ++x) {
        int sx = int(q.x) + x;
        if (sx < 0 || sx >= int(source.get_width())) continue;
        float weight = weights[x + radius];
        value += float4(source.read(uint2(sx, q.y))) * weight;
        total += weight;
    }
    temporary.write(value / total, q);
}

kernel void ClarityVertical(texture2d<float, access::read> source [[texture(0)]],
                            texture2d<float, access::read> temporary [[texture(1)]],
                            texture2d<float, access::write> output [[texture(2)]],
                            constant int &radius [[buffer(0)]],
                            constant float *weights [[buffer(1)]],
                            constant float &intensity [[buffer(2)]],
                            uint2 q [[thread_position_in_grid]]) {
    if (q.x >= source.get_width() || q.y >= source.get_height()) return;
    float4 value = 0;
    float total = 0;
    for (int y = -radius; y <= radius; ++y) {
        int sy = int(q.y) + y;
        if (sy < 0 || sy >= int(source.get_height())) continue;
        float weight = weights[y + radius];
        value += temporary.read(uint2(q.x, sy)) * weight;
        total += weight;
    }
    float4 center = float4(source.read(q));
    float4 result = center + (center - value / total) * intensity;
    result.a = center.a;
    output.write(result, q);
}
