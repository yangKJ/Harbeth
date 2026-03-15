//
//  C7BilateralBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BilateralBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *sigmaSpace [[buffer(0)]],
                            constant float *sigmaColor [[buffer(1)]],
                            constant float *blurRadius [[buffer(2)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    uint2 centralPixel = uint2(x, y);
    half4 centralColor = inputTexture.read(centralPixel);
    
    int radius = int(*blurRadius);
    if (radius < 1) radius = 1;
    
    half4 sum = half4(0.0, 0.0, 0.0, 0.0);
    half weightSum = 0.0;
    
    float sigmaSpaceSquared = *sigmaSpace * *sigmaSpace;
    float sigmaColorSquared = *sigmaColor * *sigmaColor;
    
    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            int2 offset = int2(i, j);
            uint2 currentPixel = uint2(clamp(int(x) + offset.x, 0, int(width) - 1),
                                       clamp(int(y) + offset.y, 0, int(height) - 1));
            half4 currentColor = inputTexture.read(currentPixel);
            float spatialDistance = sqrt(float(i * i + j * j));
            half3 colorDiff = currentColor.rgb - centralColor.rgb;
            float colorDistance = length(float3(colorDiff));
            float spatialWeight = exp(-(spatialDistance * spatialDistance) / (2.0 * sigmaSpaceSquared));
            float colorWeight = exp(-(colorDistance * colorDistance) / (2.0 * sigmaColorSquared));
            float weight = spatialWeight * colorWeight;
            sum += currentColor * half(weight);
            weightSum += half(weight);
        }
    }
    half4 outColor = sum / weightSum;
    
    outputTexture.write(outColor, grid);
}
