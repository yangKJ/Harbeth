//
//  C7Temperature.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Temperature(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *temperature [[buffer(0)]],
                          constant float *tint [[buffer(1)]],
                          constant float *colorShift [[buffer(2)]],
                          constant float *intensity [[buffer(3)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 source = inputTexture.read(grid);
    
    // YIQ color space conversion matrices
    const half3x3 RGBtoYIQ = half3x3({0.299, 0.587, 0.114}, {0.596, -0.274, -0.322}, {0.212, -0.523, 0.311});
    const half3x3 YIQtoRGB = half3x3({1.0, 0.956, 0.621}, {1.0, -0.272, -0.647}, {1.0, -1.105, 1.702});
    
    // Warm filter for temperature adjustment
    const half3 warmFilter = half3(0.93, 0.54, 0.0);
    
    // Adjust tint using YIQ color space
    half3 yiq = RGBtoYIQ * source.rgb;
    yiq.b = clamp(yiq.b + half(*tint) * 0.5226 * 0.1, -0.5226, 0.5226);
    half3 rgb = YIQtoRGB * yiq;
    
    // Apply warm filter based on temperature (overlay blend, HDR-safe)
    // For values outside 0–1, extrapolate linearly to preserve extended range.
    half3 processed;
    for (int i = 0; i < 3; i++) {
        half v = rgb[i];
        half w = warmFilter[i];
        if (v < 0.0h || v > 1.0h) {
            // Outside SDR range: linearly extrapolate from the nearest boundary.
            // Overlay derivative at v=0 is 2*w, at v=1 is 2*(1-w).
            if (v < 0.0h) {
                processed[i] = v * (2.0h * w);
            } else {
                processed[i] = 1.0h + 2.0h * (1.0h - w) * (v - 1.0h);
            }
        } else if (v < 0.5h) {
            processed[i] = 2.0h * v * w;
        } else {
            processed[i] = 1.0h - 2.0h * (1.0h - v) * (1.0h - w);
        }
    }

    // Blend based on temperature factor
    half tempFactor = half(*temperature);
    // Adjust for intuitive control: positive temperature = warmer, negative = cooler
    tempFactor = (tempFactor + 1.0) * 0.5; // Convert from [-1,1] to [0,1]

    half3 tempAdjusted = mix(rgb, processed, tempFactor);

    // Apply color shift (cyan to magenta)
    half shift = half(*colorShift);
    if (shift != 0.0) {
        if (shift > 0.0) {
            // Magenta shift
            tempAdjusted.r = tempAdjusted.r + shift * 0.2;
            tempAdjusted.b = tempAdjusted.b + shift * 0.2;
            tempAdjusted.g = tempAdjusted.g - shift * 0.1;
        } else {
            // Cyan shift
            tempAdjusted.g = tempAdjusted.g - shift * 0.2;
            tempAdjusted.b = tempAdjusted.b - shift * 0.2;
            tempAdjusted.r = tempAdjusted.r + shift * 0.1;
        }
    }

    // Apply intensity (no clamping — preserve HDR extended range)
    half3 finalRGB = mix(source.rgb, tempAdjusted, half(*intensity));
    
    // Output result
    const half4 outColor = half4(finalRGB, source.a);
    outputTexture.write(outColor, grid);
}
