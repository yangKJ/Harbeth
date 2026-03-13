//
//  C7TiltShift.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

// 高斯模糊函数
float4 gaussianBlur(texture2d<half, access::read> texture, uint2 position, float blurRadius, uint2 size) {
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

kernel void C7TiltShift(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      constant float *blurRadius [[buffer(0)]],
                      constant float *center [[buffer(1)]],
                      constant float *size [[buffer(2)]],
                      constant float *transition [[buffer(3)]],
                      constant float *isLinear [[buffer(4)]],
                      uint2 grid [[thread_position_in_grid]]) {
    
    const float4 inColor = float4(inputTexture.read(grid));
    const uint2 textureSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    
    float blurAmount = *blurRadius;
    float centerPoint = *center;
    float clearSize = *size;
    float transitionSize = *transition;
    bool linearMode = *isLinear > 0.5;
    
    // 计算像素到清晰区域的距离
    float distance = 0.0;
    
    if (linearMode) {
        // 线性模式：计算垂直距离
        float pixelY = float(grid.y) / float(textureSize.y);
        distance = abs(pixelY - centerPoint);
    } else {
        // 径向模式：计算到中心点的距离
        float2 centerCoord = float2(textureSize.x * 0.5, textureSize.y * centerPoint);
        float2 pixelCoord = float2(grid.x, grid.y);
        float2 delta = pixelCoord - centerCoord;
        distance = length(delta) / length(float2(textureSize.x * 0.5, textureSize.y * 0.5));
    }
    
    // 计算模糊强度
    float blurStrength = 0.0;
    float clearHalfSize = clearSize * 0.5;
    
    if (distance > clearHalfSize) {
        float transitionStart = clearHalfSize;
        float transitionEnd = clearHalfSize + transitionSize;
        
        if (distance > transitionEnd) {
            blurStrength = 1.0;
        } else if (distance > transitionStart) {
            // 平滑过渡
            blurStrength = (distance - transitionStart) / (transitionEnd - transitionStart);
        }
    }
    
    // 应用模糊
    float4 blurredColor = gaussianBlur(inputTexture, grid, blurAmount * 10.0, textureSize);
    float4 finalColor = mix(inColor, blurredColor, blurStrength * blurAmount);
    
    outputTexture.write(half4(finalColor), grid);
}
