//
//  C7TiltShift.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7TiltShiftComposite(texture2d<float, access::write> outputTexture [[texture(0)]],
                      texture2d<float, access::read> inputTexture [[texture(1)]],
                      texture2d<float, access::read> blurredTexture [[texture(2)]],
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
    
    if (!isfinite(*blurRadius) || *blurRadius <= 0 || !isfinite(*center) || !isfinite(*size) || !isfinite(*transition)) {
        outputTexture.write(inColor, grid); return;
    }
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
    
    float4 blurredColor = float4(blurredTexture.read(grid));
    float4 finalColor = mix(inColor, blurredColor, blurStrength * blurAmount);
    
    outputTexture.write(finalColor, grid);
}

kernel void C7TiltShiftPass(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      constant float *blurRadius [[buffer(0)]], constant float *horizontal [[buffer(1)]], constant float *weights [[buffer(2)]],
                      uint2 grid [[thread_position_in_grid]]) {
    if (!isfinite(*blurRadius)) { outputTexture.write(inputTexture.read(grid), grid); return; }
    int radius = int(ceil(clamp(*blurRadius * 100.0f, 0.0f, 100.0f)));
    if (radius == 0) { outputTexture.write(inputTexture.read(grid), grid); return; }
    float4 sum = float4(0.0f); float total = 0.0f;
    int2 size = int2(inputTexture.get_width(), inputTexture.get_height());
    for (int i = -radius; i <= radius; ++i) {
        int2 p = int2(grid) + ((*horizontal > 0.5f) ? int2(i, 0) : int2(0, i));
        p = clamp(p, int2(0), size - 1);
        float w = weights[i + radius];
        sum += float4(inputTexture.read(uint2(p))) * w; total += w;
    }
    outputTexture.write(half4(sum / total), grid);
}
