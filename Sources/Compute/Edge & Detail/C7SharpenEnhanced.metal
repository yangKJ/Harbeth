//
//  C7SharpenEnhanced.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SharpenEnhanced(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *intensity [[buffer(0)]],
                              constant float *threshold [[buffer(1)]],
                              constant float *kernelSize [[buffer(2)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const int width = inputTexture.get_width();
    const int height = inputTexture.get_height();
    const int x = int(grid.x);
    const int y = int(grid.y);
    
    const int kSize = int(*kernelSize);
    const int kernelRadius = kSize / 2;
    
    // Calculate the blur
    float4 blurColor = float4(0.0);
    int blurCount = 0;
    
    for (int i = -kernelRadius; i <= kernelRadius; i++) {
        for (int j = -kernelRadius; j <= kernelRadius; j++) {
            // Skip the center pixel for blur calculation
            if (i == 0 && j == 0) continue;
            
            int pixelX = clamp(x + i, 0, width - 1);
            int pixelY = clamp(y + j, 0, height - 1);
            blurColor += float4(inputTexture.read(uint2(pixelX, pixelY)));
            blurCount++;
        }
    }
    
    blurColor /= float(blurCount);
    
    // Get the original color
    float4 originalColor = float4(inputTexture.read(grid));
    
    // Calculate the edge difference
    float4 edge = originalColor - blurColor;
    float edgeStrength = length(edge.rgb);
    
    // Apply threshold
    float thresholdValue = float(*threshold);
    if (edgeStrength < thresholdValue) {
        // No sharpening for low contrast areas
        outputTexture.write(half4(originalColor), grid);
        return;
    }
    
    // Apply sharpening
    float sharpenIntensity = float(*intensity);
    float4 sharpenedColor = originalColor + edge * sharpenIntensity;
    sharpenedColor.rgb = clamp(sharpenedColor.rgb, 0.0, 1.0);
    
    outputTexture.write(half4(sharpenedColor), grid);
}
