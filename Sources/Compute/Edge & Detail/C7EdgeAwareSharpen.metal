//
//  C7EdgeAwareSharpen.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7EdgeAwareSharpen(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> inputTexture [[texture(1)]],
                               constant float &amount [[buffer(0)]],
                               constant float &edgeThreshold [[buffer(1)]],
                               uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    half4 centerColor = inputTexture.read(grid);
    
    constexpr int kernelSize = 3;
    const half laplacianKernel[9] = {
        0.0h,  1.0h, 0.0h,
        1.0h, -4.0h, 1.0h,
        0.0h,  1.0h, 0.0h
    };
    
    half4 laplacianSum = half4(0.0h);
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            uint2 samplePos = uint2(grid.x + x, grid.y + y);
            if (samplePos.x < inputTexture.get_width() && samplePos.y < inputTexture.get_height()) {
                half4 sampleColor = inputTexture.read(samplePos);
                int kernelIndex = (y + 1) * kernelSize + (x + 1);
                laplacianSum += sampleColor * laplacianKernel[kernelIndex];
            }
        }
    }
    
    half edgeStrength = dot(abs(laplacianSum.rgb), half3(0.299h, 0.587h, 0.114h));
    edgeStrength = saturate(edgeStrength / 4.0h);
    
    half sharpenIntensity = 0.0h;
    if (edgeStrength > half(edgeThreshold)) {
        half normalizedEdge = (edgeStrength - half(edgeThreshold)) / (1.0h - half(edgeThreshold));
        sharpenIntensity = half(amount) * normalizedEdge;
    }
    
    half4 sharpenedColor = centerColor - laplacianSum * sharpenIntensity * 0.25h;
    sharpenedColor = clamp(sharpenedColor, half4(0.0h), half4(1.0h));
    sharpenedColor.a = centerColor.a;
    
    outputTexture.write(sharpenedColor, grid);
}
