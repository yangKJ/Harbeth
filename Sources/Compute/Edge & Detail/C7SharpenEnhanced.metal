//
//  C7SharpenEnhanced.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SharpenEnhanced(texture2d<float, access::write> outputTexture [[texture(0)]],
                              texture2d<float, access::read> inputTexture [[texture(1)]],
                              constant float *intensity [[buffer(0)]],
                              constant float *threshold [[buffer(1)]],
                              constant float *kernelSize [[buffer(2)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const int width = inputTexture.get_width();
    const int height = inputTexture.get_height();
    const int x = int(grid.x);
    const int y = int(grid.y);
    
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    if (!isfinite(*intensity) || !isfinite(*threshold) || !isfinite(*kernelSize) || *intensity == 0.0f) { outputTexture.write(inputTexture.read(grid), grid); return; }
    const int kSize = int(clamp(*kernelSize, 1.0f, 5.0f));
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
    
    if (blurCount == 0) { outputTexture.write(inputTexture.read(grid), grid); return; }
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
        outputTexture.write(float4(originalColor), grid);
        return;
    }
    
    // Apply sharpening
    float sharpenIntensity = float(*intensity);
    float4 sharpenedColor = originalColor + edge * sharpenIntensity;
    
    outputTexture.write(float4(sharpenedColor), grid);
}
