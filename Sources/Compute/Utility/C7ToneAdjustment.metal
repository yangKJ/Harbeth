//
//  C7ToneAdjustment.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ToneAdjustment(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *shadows [[buffer(0)]],
                             constant float *highlights [[buffer(1)]],
                             constant float *midtones [[buffer(2)]],
                             constant float *contrast [[buffer(3)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half shadowAmount = half(*shadows);
    const half highlightAmount = half(*highlights);
    const half midtoneAmount = half(*midtones);
    const half contrastAmount = half(*contrast);
    
    half3 color = inColor.rgb;
    
    if (shadowAmount != 0.0h) {
        half3 shadowAdjustment = max(0.0h, 1.0h - color) * abs(shadowAmount) * 0.5h;
        if (shadowAmount > 0.0h) {
            color += shadowAdjustment;
        } else {
            color -= shadowAdjustment;
        }
    }
    
    if (highlightAmount != 0.0h) {
        half3 highlightAdjustment = max(0.0h, color - 0.5h) * abs(highlightAmount) * 0.5h;
        if (highlightAmount > 0.0h) {
            color += highlightAdjustment;
        } else {
            color -= highlightAdjustment;
        }
    }
    
    if (midtoneAmount != 0.0h) {
        half3 midtoneAdjustment = abs(color - 0.5h) * abs(midtoneAmount) * 0.3h;
        if (midtoneAmount > 0.0h) {
            color += midtoneAdjustment;
        } else {
            color -= midtoneAdjustment;
        }
    }
    
    half contrastFactor = 1.0h + contrastAmount * 0.5h;
    color = ((color - 0.5h) * contrastFactor) + 0.5h;
    color = clamp(color, 0.0h, 1.0h);
    const half4 outColor = half4(color, inColor.a);
    
    outputTexture.write(outColor, grid);
}
