//
//  C7OilPaintingEnhanced.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7OilPaintingEnhanced(texture2d<half, access::write> outputTexture [[texture(0)]],
                                  texture2d<half, access::read> inputTexture [[texture(1)]],
                                  constant float *brushSize [[buffer(0)]],
                                  constant float *intensity [[buffer(1)]],
                                  constant float *smoothing [[buffer(2)]],
                                  uint2 grid [[thread_position_in_grid]]) {
    const int width = inputTexture.get_width();
    const int height = inputTexture.get_height();
    const int x = int(grid.x);
    const int y = int(grid.y);
    
    const int kernelSize = int(*brushSize);
    const int kernelRadius = kernelSize / 2;
    
    // Calculate color bins
    const int numBins = 8;
    float4 binColors[8] = {float4(0.0)};
    int binCounts[8] = {0};
    
    // Sample neighborhood
    for (int i = -kernelRadius; i <= kernelRadius; i++) {
        for (int j = -kernelRadius; j <= kernelRadius; j++) {
            int pixelX = clamp(x + i, 0, width - 1);
            int pixelY = clamp(y + j, 0, height - 1);
            float4 color = float4(inputTexture.read(uint2(pixelX, pixelY)));
            
            // Quantize color to bin
            int rBin = int(color.r * float(numBins - 1));
            int gBin = int(color.g * float(numBins - 1));
            int bBin = int(color.b * float(numBins - 1));
            int binIndex = (rBin * numBins * numBins) + (gBin * numBins) + bBin;
            binIndex = clamp(binIndex, 0, numBins - 1);
            
            binColors[binIndex] += color;
            binCounts[binIndex]++;
        }
    }
    
    // Find most frequent color bin
    int maxCount = 0;
    int maxBin = 0;
    for (int i = 0; i < numBins; i++) {
        if (binCounts[i] > maxCount) {
            maxCount = binCounts[i];
            maxBin = i;
        }
    }
    
    // Calculate average color for most frequent bin
    float4 averageColor = binColors[maxBin] / float(maxCount);
    
    // Apply intensity
    averageColor.rgb *= float(*intensity);
    averageColor.rgb = clamp(averageColor.rgb, 0.0, 1.0);
    
    // Apply smoothing
    float4 originalColor = float4(inputTexture.read(grid));
    float4 finalColor = mix(originalColor, averageColor, float(*smoothing));
    
    // Add brush stroke effect
    float2 uv = float2(float(x) / float(width), float(y) / float(height));
    float brushNoise = sin(uv.x * 100.0) * cos(uv.y * 100.0) * 0.02;
    finalColor.rgb += brushNoise;
    finalColor.rgb = clamp(finalColor.rgb, 0.0, 1.0);
    
    outputTexture.write(half4(finalColor), grid);
}
