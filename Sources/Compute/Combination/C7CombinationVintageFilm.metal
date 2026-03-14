//
//  C7CombinationVintageFilm.metal
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationVintageFilm(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> inputTexture [[texture(1)]],
                                    texture2d<half, access::read> processedTexture [[texture(2)]],
                                    constant float *intensity [[buffer(0)]],
                                    constant float *grainIntensity [[buffer(1)]],
                                    constant float *vignette [[buffer(2)]],
                                    constant float *sepiaTone [[buffer(3)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    // Get the dimensions of the input texture
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    // Read the original and processed pixels
    half4 originalColor = inputTexture.read(gid);
    half4 processedColor = processedTexture.read(gid);
    
    // Blend the original and processed colors based on intensity
    half blendIntensity = half(*intensity);
    half4 finalColor = mix(originalColor, processedColor, blendIntensity);
    
    // Apply sepia tone adjustment
    half sepiaValue = half(*sepiaTone);
    if (sepiaValue > 0.0) {
        half3 sepiaColor = half3(0.7, 0.4, 0.2);
        half intensity = dot(finalColor.rgb, half3(0.299, 0.587, 0.114));
        half3 sepiaToned = intensity * sepiaColor;
        finalColor.rgb = mix(finalColor.rgb, sepiaToned, sepiaValue * blendIntensity);
    }
    
    // Apply vignette effect
    half vignetteValue = half(*vignette);
    if (vignetteValue > 0.0) {
        float2 center = float2(width, height) * 0.5;
        float2 pos = float2(gid.x, gid.y);
        float distance = length(pos - center) / length(center);
        float vignette = 1.0 - distance * vignetteValue;
        finalColor.rgb *= half(vignette);
    }
    
    // Apply film grain effect
    half grainValue = half(*grainIntensity);
    if (grainValue > 0.0) {
        float2 st = float2(gid.x, gid.y) / float2(width, height);
        float noise = fract(sin(dot(st * float2(width, height), float2(12.9898, 78.233)) * 43758.5453123));
        noise = (noise - 0.5) * grainValue * 0.2;
        finalColor.rgb += half(noise);
    }
    
    finalColor.r += 0.05 * blendIntensity;
    finalColor.g -= 0.02 * blendIntensity;
    finalColor.rgb = clamp(finalColor.rgb, half3(0.0), half3(1.0));
    
    // Write the result to the output texture
    outputTexture.write(finalColor, gid);
}
