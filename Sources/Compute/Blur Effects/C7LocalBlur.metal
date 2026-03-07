//
//  C7LocalBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LocalBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *radius [[buffer(0)]],
                        constant float *centerX [[buffer(1)]],
                        constant float *centerY [[buffer(2)]],
                        constant float *size [[buffer(3)]],
                        constant float *softness [[buffer(4)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const int width = inputTexture.get_width();
    const int height = inputTexture.get_height();
    const int x = int(grid.x);
    const int y = int(grid.y);
    
    // Calculate pixel distance from center
    float2 pixelPos = float2(float(x) / float(width), float(y) / float(height));
    float2 centerPos = float2(*centerX, *centerY);
    float distance = length(pixelPos - centerPos);
    
    // Calculate blur strength based on distance
    float blurSize = *size * 0.5; // Normalize size
    float blurSoftness = *softness;
    float blurStrength = smoothstep(blurSize, blurSize - blurSoftness, distance);
    blurStrength = clamp(blurStrength, 0.0, 1.0);
    
    if (blurStrength < 0.01) {
        // No blur, just copy the original pixel
        outputTexture.write(inputTexture.read(grid), grid);
        return;
    }
    
    // Calculate Gaussian blur
    int kernelSize = int(ceil(*radius) * 2 + 1);
    int kernelRadius = kernelSize / 2;
    float sigma = *radius / 3.0;
    float sigma2 = sigma * sigma;
    
    float4 blurredColor = float4(0.0);
    float weightSum = 0.0;
    
    for (int i = -kernelRadius; i <= kernelRadius; i++) {
        for (int j = -kernelRadius; j <= kernelRadius; j++) {
            int pixelX = clamp(x + i, 0, width - 1);
            int pixelY = clamp(y + j, 0, height - 1);
            
            // Calculate Gaussian weight
            float distance2 = float(i * i + j * j);
            float weight = exp(-distance2 / (2.0 * sigma2));
            
            blurredColor += float4(inputTexture.read(uint2(pixelX, pixelY))) * weight;
            weightSum += weight;
        }
    }
    
    blurredColor /= weightSum;
    
    // Get original color
    float4 originalColor = float4(inputTexture.read(grid));
    
    // Mix original and blurred color based on blur strength
    float4 finalColor = mix(originalColor, blurredColor, blurStrength);
    
    outputTexture.write(half4(finalColor), grid);
}
