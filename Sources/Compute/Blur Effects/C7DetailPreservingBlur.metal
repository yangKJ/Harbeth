//
//  C7DetailPreservingBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7DetailPreservingBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   constant float &strength [[buffer(0)]],
                                   constant float &detailPreservation [[buffer(1)]],
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
    half4 highFrequencyDetail = centerColor - blurredColor;
    half4 detailPreserved = blurredColor + highFrequencyDetail * half(detailPreservation);
    half4 finalColor = mix(centerColor, detailPreserved, half(strength));
    
    outputTexture.write(finalColor, grid);
}
