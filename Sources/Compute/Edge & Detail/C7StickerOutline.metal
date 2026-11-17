// 由 Condy 维护。最近邻证明饱和时省去完整搜索，其余路径保留原算法。
#include <metal_stdlib>
using namespace metal;

constant bool stickerUsesSIMDGroup [[function_constant(0)]];
// 包装滤镜未传递特化参数时，仍可使用不要求 SIMD 能力的内核。
constant bool stickerGroupPruning = is_function_constant_defined(stickerUsesSIMDGroup) ? stickerUsesSIMDGroup : false;

static inline __attribute__((always_inline)) void outlinePixel(texture2d<float, access::write> outputTexture,
                  texture2d<float, access::read> inputTexture,
                  bool flat,
                  constant float *outlineThickness,
                  constant float *outlineBlur,
                  constant float4 *colorVector,
                  constant float &halfOutput,
                  uint2 grid) {
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
    
    if (flat) {
        outputTexture.write(halfOutput > 0.5f ? float4(half4(originalColor)) : originalColor, grid); return;
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

kernel void C7StickerOutline(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             constant float *outlineThickness [[buffer(0)]],
                             constant float *outlineBlur [[buffer(1)]],
                             constant float4 *colorVector [[buffer(2)]],
                             constant float &halfOutput [[buffer(3)]],
                             uint2 grid [[thread_position_in_grid]]) {
    outlinePixel(outputTexture, inputTexture, false, outlineThickness, outlineBlur, colorVector, halfOutput, grid);
}

kernel void C7StickerOutlineClassified(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             texture2d<uint, access::read> flags [[texture(2)]],
                             constant float *outlineThickness [[buffer(0)]],
                             constant float *outlineBlur [[buffer(1)]],
                             constant float4 *colorVector [[buffer(2)]],
                             constant float &halfOutput [[buffer(3)]],
                             uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    outlinePixel(outputTexture, inputTexture, flags.read(grid / 16).r != 0, outlineThickness, outlineBlur, colorVector, halfOutput, grid);
}

// 仅完整范围证明才能写入平坦标记；稀疏反例只能让本组回退原搜索。
kernel void outlineClassifyFlat(texture2d<uint, access::write> flags [[texture(0)]],
                                texture2d<float, access::read> source [[texture(1)]],
                                constant uint &radius [[buffer(0)]],
                                uint2 group [[threadgroup_position_in_grid]],
                                uint lane [[thread_index_in_threadgroup]]) {
    const int2 maximum = int2(source.get_width() - 1, source.get_height() - 1);
    const int2 origin = int2(group) * 16 - int2(radius);
    const int2 first = clamp(origin, int2(0), maximum);
    const float3 a = source.read(uint2(first)).rgb;
    const float3 b = source.read(uint2(clamp(first + int2(1, 0), int2(0), maximum))).rgb;
    const float3 c = source.read(uint2(clamp(first + int2(0, 1), int2(0), maximum))).rgb;
    if (!all(isfinite(a)) || !all(isfinite(b)) || !all(isfinite(c)) || length(a - b) >= 0.29999f || length(a - c) >= 0.29999f) {
        if (lane == 0) flags.write(uint4(0), group);
        return;
    }
    const uint side = 16 + 2 * radius;
    threadgroup float4 lows[64], highs[64];
    float3 low = float3(INFINITY), high = float3(-INFINITY);
    bool valid = true;
    for (uint i = lane; i < side * side; i += 64) {
        const int2 p = clamp(origin + int2(i % side, i / side), int2(0), maximum);
        const float3 v = source.read(uint2(p)).rgb;
        valid = valid && all(isfinite(v));
        low = min(low, v); high = max(high, v);
    }
    lows[lane] = float4(low, valid ? 1.0f : 0.0f); highs[lane] = float4(high, 0);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = 32; stride > 0; stride >>= 1) {
        if (lane < stride) {lows[lane] = min(lows[lane], lows[lane + stride]);highs[lane] = max(highs[lane], highs[lane + stride]);}
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) flags.write(uint4(lows[0].w > 0.5f && length(highs[0].xyz - lows[0].xyz) < 0.29999f ? 1 : 0), group);
}
