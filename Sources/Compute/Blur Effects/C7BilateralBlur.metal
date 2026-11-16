//
//  C7BilateralBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BilateralBlur(texture2d<float, access::write> outputTexture [[texture(0)]],
                            texture2d<float, access::read> inputTexture [[texture(1)]],
                            constant float *sigmaSpace [[buffer(0)]],
                            constant float *sigmaColor [[buffer(1)]],
                            constant float *blurRadius [[buffer(2)]],
                            constant float *spatialWeights [[buffer(3)]],
                            constant float &usesSpatialWeights [[buffer(4)]],
                            uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    uint2 centralPixel = uint2(x, y);
    float4 centralColor = inputTexture.read(centralPixel);

    if (!isfinite(*sigmaSpace) || !isfinite(*sigmaColor) || *sigmaSpace <= 0.0f || *sigmaColor <= 0.0f || !isfinite(*blurRadius) || *blurRadius <= 0.0f) {
        outputTexture.write(centralColor, grid);
        return;
    }
    
    int radius = int(*blurRadius);
    if (radius < 1) radius = 1;
    
    float4 sum = float4(0.0);
    float weightSum = 0.0;
    
    float sigmaSpaceSquared = *sigmaSpace * *sigmaSpace;
    float sigmaColorSquared = *sigmaColor * *sigmaColor;
    
    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            int2 offset = int2(i, j);
            uint2 currentPixel = uint2(clamp(int(x) + offset.x, 0, int(width) - 1),
                                       clamp(int(y) + offset.y, 0, int(height) - 1));
            float4 currentColor = inputTexture.read(currentPixel);
            float spatialDistanceSquared = float(i * i + j * j);
            float3 colorDiff = currentColor.rgb - centralColor.rgb;
            float colorDistanceSquared = dot(float3(colorDiff), float3(colorDiff));
            float spatialWeight = usesSpatialWeights > 0.5f ? spatialWeights[i + radius] * spatialWeights[j + radius]
                : exp(-(spatialDistanceSquared) / (2.0 * sigmaSpaceSquared));
            float exponent = colorDistanceSquared == 0 ? 0 : colorDistanceSquared / (2.0 * sigmaColorSquared);
            float colorWeight = exp(-exponent);
            float weight = spatialWeight * colorWeight;
            sum += float4(currentColor) * weight;
            weightSum += weight;
        }
    }
    float4 outColor = float4(sum / max(weightSum, 1e-20f));
    
    outputTexture.write(outColor, grid);
}
