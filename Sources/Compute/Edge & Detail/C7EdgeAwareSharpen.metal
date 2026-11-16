//
//  C7EdgeAwareSharpen.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7EdgeAwareSharpen(texture2d<float, access::write> outputTexture [[texture(0)]],
                               texture2d<float, access::read> inputTexture [[texture(1)]],
                               constant float &amount [[buffer(0)]],
                               constant float &edgeThreshold [[buffer(1)]],
                               uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    float4 centerColor = float4(inputTexture.read(grid));
    if (!isfinite(amount) || !isfinite(edgeThreshold) || amount == 0.0f || edgeThreshold >= 1.0f) { outputTexture.write(centerColor, grid); return; }
    
    constexpr int kernelSize = 3;
    const float laplacianKernel[9] = {
        0.0f,  1.0f, 0.0f,
        1.0f, -4.0f, 1.0f,
        0.0f,  1.0f, 0.0f
    };
    
    float4 laplacianSum = float4(0.0f);
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            const int2 coordinate = int2(grid) + int2(x, y);
            const int2 maximum = int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1);
            const uint2 samplePos = uint2(clamp(coordinate, int2(0), maximum));
            float4 sampleColor = float4(inputTexture.read(samplePos));
            int kernelIndex = (y + 1) * kernelSize + (x + 1);
            laplacianSum += sampleColor * laplacianKernel[kernelIndex];
        }
    }
    
    float edgeStrength = saturate(dot(abs(laplacianSum.rgb), float3(0.299f, 0.587f, 0.114f)) / 4.0f);
    
    float sharpenIntensity = 0.0f;
    if (edgeStrength > edgeThreshold) {
        float normalizedEdge = (edgeStrength - edgeThreshold) / (1.0f - edgeThreshold);
        sharpenIntensity = amount * normalizedEdge;
    }
    
    float4 sharpenedColor = centerColor - laplacianSum * sharpenIntensity * 0.25f;
    sharpenedColor.a = centerColor.a;
    
    outputTexture.write(sharpenedColor, grid);
}
