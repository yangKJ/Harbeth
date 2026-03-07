#include <metal_stdlib>
using namespace metal;

kernel void C7StickerOutline(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *factors [[buffer(0)]],
                             constant float *colorFactor [[buffer(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const float thickness = factors[0];
    const float blur = factors[1];
    const float4 outlineColor = float4(colorFactor[0], colorFactor[1], colorFactor[2], colorFactor[3]);
    
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();
    
    // 采样原始纹理
    const half4 originalHalfColor = inputTexture.read(grid);
    const float4 originalColor = float4(float(originalHalfColor.r), float(originalHalfColor.g), float(originalHalfColor.b), float(originalHalfColor.a));
    
    // 如果像素完全透明，直接输出透明
    if (originalColor.a < 0.1) {
        outputTexture.write(half4(0.0), grid);
        return;
    }
    
    // 检查周围像素的颜色差异，判断是否在边缘
    bool isEdge = false;
    float edgeStrength = 0.0;
    
    const int kernelSize = max(1, int(thickness * float(width))); // 确保 kernelSize 至少为 1
    const float colorThreshold = 0.3; // 颜色差异阈值
    
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            if (x == 0 && y == 0) continue;
            
            const int2 offset = int2(x, y);
            const int2 samplePos = int2(grid) + offset;
            
            if (samplePos.x >= 0 && samplePos.x < int(width) && samplePos.y >= 0 && samplePos.y < int(height)) {
                const half4 sampleHalfColor = inputTexture.read(uint2(samplePos));
                const float4 sampleColor = float4(float(sampleHalfColor.r), float(sampleHalfColor.g), float(sampleHalfColor.b), float(sampleHalfColor.a));
                
                // 计算颜色差异
                const float colorDiff = length(sampleColor.rgb - originalColor.rgb);
                
                if (colorDiff > colorThreshold) {
                    isEdge = true;
                    // 计算边缘强度，距离越近强度越大，颜色差异越大强度越大
                    const float distance = sqrt(float(x*x + y*y));
                    const float distanceFactor = 1.0 - distance / float(kernelSize);
                    const float colorFactorValue = colorDiff;
                    const float strength = distanceFactor * colorFactorValue;
                    edgeStrength = max(edgeStrength, strength);
                }
            }
        }
    }
    
    if (isEdge) {
        // 归一化边缘强度到 0.0-1.0 范围
        const float normalizedEdgeStrength = min(edgeStrength, 1.0);
        
        // 混合原始颜色和轮廓颜色，使用更明显的轮廓颜色
        const float4 edgeColor = mix(originalColor, outlineColor, normalizedEdgeStrength * 0.8);
        
        if (blur > 0.0) {
            // 实现边缘模糊效果
            const int blurRadius = max(1, int(blur * float(kernelSize) * 2.0)); // 确保 blurRadius 至少为 1
            float4 blurredColor = edgeColor;
            float weightSum = 1.0;
            
            for (int x = -blurRadius; x <= blurRadius; x++) {
                for (int y = -blurRadius; y <= blurRadius; y++) {
                    if (x == 0 && y == 0) continue;
                    
                    const int2 offset = int2(x, y);
                    const int2 samplePos = int2(grid) + offset;
                    
                    if (samplePos.x >= 0 && samplePos.x < int(width) && samplePos.y >= 0 && samplePos.y < int(height)) {
                        const half4 sampleHalfColor = inputTexture.read(uint2(samplePos));
                        const float4 sampleColor = float4(float(sampleHalfColor.r), float(sampleHalfColor.g), float(sampleHalfColor.b), float(sampleHalfColor.a));
                        
                        // 计算距离权重
                        const float distance = sqrt(float(x*x + y*y));
                        const float weight = 1.0 / (1.0 + distance * 0.5);
                        
                        blurredColor += sampleColor * weight;
                        weightSum += weight;
                    }
                }
            }
            
            // 避免除零错误
            if (weightSum > 0.0) {
                blurredColor /= weightSum;
            }
            
            // 混合原始边缘颜色和模糊颜色
            const float4 finalColor = mix(edgeColor, blurredColor, blur);
            outputTexture.write(half4(finalColor), grid);
        } else {
            // 无模糊，直接使用边缘颜色
            outputTexture.write(half4(edgeColor), grid);
        }
    } else {
        // 非边缘区域，保持原始颜色
        outputTexture.write(half4(originalColor), grid);
    }
}
