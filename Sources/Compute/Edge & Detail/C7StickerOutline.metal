// 由 Condy 维护。最近邻证明饱和时省去完整搜索，其余路径保留原算法。
#include <metal_stdlib>
using namespace metal;

constant bool stickerUsesSIMDGroup [[function_constant(0)]];
// 包装滤镜未传递特化参数时，仍可使用不要求 SIMD 能力的内核。
constant bool stickerGroupPruning = is_function_constant_defined(stickerUsesSIMDGroup) ? stickerUsesSIMDGroup : false;

kernel void C7StickerOutline(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             constant float *outlineThickness [[buffer(0)]],
                             constant float *outlineBlur [[buffer(1)]],
                             constant float4 *colorVector [[buffer(2)]],
                             constant float &halfOutput [[buffer(3)]],
                             uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float thickness = *outlineThickness;
    const float blur = *outlineBlur;
    const float4 outlineColor = float4(*colorVector);
    
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();
    
    // 采样原始纹理
    const float4 originalColor = inputTexture.read(grid);
    // 零厚度关闭效果，必须先于旧的软透明裁除规则。
    if (!isfinite(thickness) || thickness <= 0.0f) { outputTexture.write(originalColor, grid); return; }

    // 正厚度路径保留原有的低 alpha 裁除。
    if (originalColor.a < 0.1) {
        outputTexture.write(float4(0), grid);
        return;
    }
    
    // 检查周围像素的颜色差异，判断是否在边缘
    bool isEdge = false;
    float edgeStrength = 0.0;
    
    const int kernelSize = max(1, int(thickness * float(width)));
    const float colorThreshold = 0.3; // 颜色差异阈值
    
    if (kernelSize > 1) {
        const int2 offsets[4] = {int2(1, 0), int2(0, 1), int2(-1, 0), int2(0, -1)};
        float lowerBound = 0.0f;
        for (uint i = 0; i < 4; i++) {
            const int2 point = int2(grid) + offsets[i];
            if (point.x >= 0 && point.y >= 0 && point.x < int(width) && point.y < int(height)) {
                const float3 delta = inputTexture.read(uint2(point)).rgb - originalColor.rgb;
                lowerBound = max(lowerBound, length(delta));
            }
        }
        const bool saturated = lowerBound * (1.0f - 1.0f / float(kernelSize)) >= 1.00001f;
        // 支持时按组统一剪枝，避免混合内容的线程分歧；其他设备保留逐像素证明。
        if (stickerGroupPruning ? simd_all(saturated) : saturated) {
            isEdge = true; edgeStrength = 1.0f;
        }
    }
    if (edgeStrength < 1.0f) for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            if (x == 0 && y == 0) continue;
            
            const int2 offset = int2(x, y);
            const int2 samplePos = int2(grid) + offset;
            
            if (samplePos.x >= 0 && samplePos.x < int(width) && samplePos.y >= 0 && samplePos.y < int(height)) {
                const float4 sampleColor = inputTexture.read(uint2(samplePos));
                
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
                        const float4 sampleColor = inputTexture.read(uint2(samplePos));
                        
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
            outputTexture.write(halfOutput > 0.5f ? float4(half4(finalColor)) : finalColor, grid);
        } else {
            // 无模糊，直接使用边缘颜色
            outputTexture.write(halfOutput > 0.5f ? float4(half4(edgeColor)) : edgeColor, grid);
        }
    } else {
        // 非边缘区域，保持原始颜色
        outputTexture.write(halfOutput > 0.5f ? float4(half4(originalColor)) : originalColor, grid);
    }
}
