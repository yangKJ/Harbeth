//
//  C7TiltShift.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

// 高斯模糊函数
float4 gaussianBlur(texture2d<half, access::read> texture, int2 position, float blurRadius, int2 size) {
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
            const int2 samplePos = clamp(position + int2(x, y), int2(0), size - 1);
            color += float4(texture.read(uint2(samplePos))) * weight;
            totalWeight += weight;
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
                      constant float4 *regionContext [[buffer(30)]],
                      uint2 grid [[thread_position_in_grid]]) {
    
    const float4 inColor = float4(inputTexture.read(grid));
    const int2 textureSize = int2(inputTexture.get_width(), inputTexture.get_height());
    const float4 outputRegion = regionContext[1];
    const float2 globalPixel = float2(grid) + outputRegion.xy;
    const float2 logicalSize = max(outputRegion.zw, float2(1.0));
    
    float blurAmount = *blurRadius;
    float centerPoint = *center;
    float clearSize = *size;
    float transitionSize = *transition;
    bool linearMode = *isLinear > 0.5;
    
    // 计算像素到清晰区域的距离
    float distance = 0.0;
    
    if (linearMode) {
        // 线性模式：计算垂直距离
        float pixelY = globalPixel.y / logicalSize.y;
        distance = abs(pixelY - centerPoint);
    } else {
        // 径向模式：计算到中心点的距离
        float2 centerCoord = float2(logicalSize.x * 0.5, logicalSize.y * centerPoint);
        float2 pixelCoord = globalPixel;
        float2 delta = pixelCoord - centerCoord;
        distance = length(delta) / length(logicalSize * 0.5);
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
    float4 blurredColor = gaussianBlur(inputTexture, int2(grid), blurAmount * 10.0, textureSize);
    float4 finalColor = mix(inColor, blurredColor, blurStrength * blurAmount);
    
    outputTexture.write(half4(finalColor), grid);
}
