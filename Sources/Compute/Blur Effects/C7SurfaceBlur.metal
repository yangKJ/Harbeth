//
//  C7SurfaceBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

float colorDifference(float4 color1, float4 color2) {
    float3 diff = color1.rgb - color2.rgb;
    return length(diff);
}

float4 surfaceBlur(texture2d<half, access::read> texture, uint2 coord, uint2 size, float radius, float threshold) {
    float4 centerColor = float4(texture.read(coord));
    float4 blurredColor = float4(0.0);
    float weightSum = 0.0;
    
    int kernelSize = int(ceil(radius) * 2 + 1);
    int halfKernelSize = kernelSize / 2;
    
    for (int x = -halfKernelSize; x <= halfKernelSize; x++) {
        for (int y = -halfKernelSize; y <= halfKernelSize; y++) {
            uint2 offset = uint2(coord.x + x, coord.y + y);
            if (offset.x < 0 || offset.x >= size.x || offset.y < 0 || offset.y >= size.y) {
                continue;
            }
            float4 sampleColor = float4(texture.read(offset));
            float spatialDistance = sqrt(float(x * x + y * y));
            float spatialWeight = exp(-spatialDistance * spatialDistance / (2.0 * radius * radius));
            
            float colorDist = colorDifference(centerColor, sampleColor);
            float colorWeight = exp(-colorDist * colorDist / (2.0 * threshold * threshold));
            float weight = spatialWeight * colorWeight;
            
            blurredColor += sampleColor * weight;
            weightSum += weight;
        }
    }
    
    if (weightSum > 0.0) {
        blurredColor /= weightSum;
    } else {
        blurredColor = centerColor;
    }
    
    return blurredColor;
}

kernel void C7SurfaceBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *factors [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    uint2 size = uint2(outputTexture.get_width(), outputTexture.get_height());
    if (grid.x >= size.x || grid.y >= size.y) {
        return;
    }
    float radius = factors[0];
    float threshold = factors[1];
    float intensity = factors[2];
    
    float4 originalColor = float4(inputTexture.read(grid));
    float4 blurredColor = surfaceBlur(inputTexture, grid, size, radius, threshold);
    float4 finalColor = mix(originalColor, blurredColor, float(intensity));
    
    outputTexture.write(half4(finalColor), grid);
}
