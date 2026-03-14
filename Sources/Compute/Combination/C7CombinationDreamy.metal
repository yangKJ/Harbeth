//
//  C7CombinationDreamy.metal
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationDreamy(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> inputTexture [[texture(1)]],
                               texture2d<half, access::read> processedTexture [[texture(2)]],
                               constant float *intensity [[buffer(0)]],
                               constant float *warmth [[buffer(1)]],
                               constant float *softness [[buffer(2)]],
                               uint2 gid [[thread_position_in_grid]]) {
    // Get the dimensions of the input texture
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    half4 processedColor = processedTexture.read(gid);
    
    // Apply warmth adjustment
    half warmthValue = half(*warmth);
    if (warmthValue != 0.0) {
        if (warmthValue > 0.0) {
            processedColor.r += warmthValue * 0.1;
            processedColor.g += warmthValue * 0.05;
        } else {
            processedColor.b += -warmthValue * 0.1;
        }
    }
    
    // Apply softness effect
    half softnessValue = half(*softness);
    if (softnessValue > 0.0) {
        half brightness = (processedColor.r + processedColor.g + processedColor.b) / 3.0;
        processedColor.rgb = mix(processedColor.rgb, half3(brightness), softnessValue * 0.3);
        half4 blurredColor = half4(0.0);
        int radius = 1;
        int sampleCount = 0;
        
        for (int i = -radius; i <= radius; i++) {
            for (int j = -radius; j <= radius; j++) {
                uint2 samplePos = gid + uint2(i, j);
                if (samplePos.x < width && samplePos.y < height) {
                    blurredColor += processedColor;
                    sampleCount++;
                }
            }
        }
        
        if (sampleCount > 0) {
            blurredColor /= half(sampleCount);
            processedColor = mix(processedColor, blurredColor, softnessValue * 0.2);
        }
    }
    
    processedColor.r *= 1.05;
    processedColor.g *= 1.02;
    processedColor.rgb = clamp(processedColor.rgb, half3(0.0), half3(1.0));
    
    // Read the original and processed pixels
    half4 originalColor = inputTexture.read(gid);
    // Blend the original and processed colors based on intensity
    half blendIntensity = half(*intensity);
    half4 finalColor = mix(originalColor, processedColor, blendIntensity);
    
    // Write the result to the output texture
    outputTexture.write(finalColor, gid);
}
