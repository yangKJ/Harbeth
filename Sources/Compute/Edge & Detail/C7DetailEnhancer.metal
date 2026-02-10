//
//  C7DetailEnhancer.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7UnsharpMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float &amount [[buffer(0)]],
                          constant float &detailThreshold [[buffer(1)]],
                          uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    
    const float gaussianKernel[25] = {
        1.0/256.0,  4.0/256.0,  6.0/256.0,  4.0/256.0, 1.0/256.0,
        4.0/256.0, 16.0/256.0, 24.0/256.0, 16.0/256.0, 4.0/256.0,
        6.0/256.0, 24.0/256.0, 36.0/256.0, 24.0/256.0, 6.0/256.0,
        4.0/256.0, 16.0/256.0, 24.0/256.0, 16.0/256.0, 4.0/256.0,
        1.0/256.0,  4.0/256.0,  6.0/256.0,  4.0/256.0, 1.0/256.0
    };
    
    half4 blurredColor = half4(0.0h);
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            uint2 samplePos = uint2(grid.x + x, grid.y + y);
            samplePos.x = clamp(samplePos.x, 0u, inputTexture.get_width() - 1);
            samplePos.y = clamp(samplePos.y, 0u, inputTexture.get_height() - 1);
            half4 sampleColor = inputTexture.read(samplePos);
            int kernelIndex = (y + 2) * 5 + (x + 2);
            blurredColor += sampleColor * half(gaussianKernel[kernelIndex]);
        }
    }
    
    half4 centerColor = inputTexture.read(grid);
    half4 mask = centerColor - blurredColor;
    half maskStrength = dot(abs(mask.rgb), half3(0.333h));
    half adaptiveAmount = half(amount);
    if (maskStrength < half(detailThreshold)) {
        adaptiveAmount *= smoothstep(0.0h, half(detailThreshold), maskStrength);
    }
    
    half4 sharpenedColor = centerColor + mask * adaptiveAmount;
    sharpenedColor = clamp(sharpenedColor, 0.0h, 1.0h);
    sharpenedColor.a = centerColor.a;
    
    outputTexture.write(sharpenedColor, grid);
}
