//
//  C7CombinationCyberpunk.metal
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationCyberpunk(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   texture2d<half, access::read> processedTexture [[texture(2)]],
                                   constant float *intensity [[buffer(0)]],
                                   constant float *neonGlow [[buffer(1)]],
                                   constant float *colorShift [[buffer(2)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    // Get the dimensions of the input texture
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    // Blend the original and processed colors based on intensity
    half blendIntensity = half(*intensity);
    half4 processedColor = processedTexture.read(gid);
    
    // Apply cyberpunk color shift
    half colorShiftValue = half(*colorShift);
    if (colorShiftValue > 0.0) {
        half temp = processedColor.r;
        processedColor.r = processedColor.b * (1.0 + colorShiftValue * 0.5);
        processedColor.b = temp * (1.0 + colorShiftValue * 0.3);
        processedColor.g *= (1.0 + colorShiftValue * 0.4);
    }
    
    // Apply neon glow effect
    half glowValue = half(*neonGlow);
    if (glowValue > 0.0) {
        half4 glowColor = half4(0.0);
        int radius = 1;
        int sampleCount = 0;
        for (int i = -radius; i <= radius; i++) {
            for (int j = -radius; j <= radius; j++) {
                uint2 samplePos = gid + uint2(i, j);
                if (samplePos.x < width && samplePos.y < height) {
                    half4 sampleColor = processedTexture.read(samplePos);
                    glowColor += sampleColor;
                    sampleCount++;
                }
            }
        }
        if (sampleCount > 0) {
            glowColor /= half(sampleCount);
            glowColor *= (1.0 + glowValue);
            processedColor = mix(processedColor, glowColor, glowValue * 0.3 * blendIntensity);
        }
    }
    
    processedColor.rgb = pow(max(processedColor.rgb, half3(0.0h)), half3(0.8));
    
    half4 originalColor = inputTexture.read(gid);
    half4 finalColor = mix(originalColor, processedColor, blendIntensity);
    
    // Write the result to the output texture
    outputTexture.write(finalColor, gid);
}
