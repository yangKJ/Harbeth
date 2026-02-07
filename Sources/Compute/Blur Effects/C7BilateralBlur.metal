//
//  C7BilateralBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BilateralBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::sample> inputTexture [[texture(1)]],
                            constant float *blurRadius [[buffer(0)]],
                            constant float *stepOffsetX [[buffer(1)]],
                            constant float *stepOffsetY [[buffer(2)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const int GAUSSIAN_SAMPLES = 9;
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    const float2 inCoordinate(x / width, y / height);
    
    int multiplier = 0;
    float2 blurStep;
    float2 singleStepOffset(float(*stepOffsetX * 10) / width, float(*stepOffsetY * 10) / height);
    float2 blurCoordinates[GAUSSIAN_SAMPLES];
    
    for (int i = 0; i < GAUSSIAN_SAMPLES; i++) {
        multiplier = (i - ((GAUSSIAN_SAMPLES - 1) / 2));
        blurStep = float(multiplier) * singleStepOffset;
        blurCoordinates[i] = inCoordinate + blurStep;
    }
    
    half4 centralColor;
    half gaussianWeightTotal;
    half4 sum;
    half4 sampleColor;
    half distanceFromCentralColor;
    half gaussianWeight;
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float distanceNormalizationFactor = float(abs(1 - *blurRadius));
    
    centralColor = inputTexture.sample(quadSampler, blurCoordinates[4]);
    gaussianWeightTotal = 0.18;
    sum = centralColor * 0.18;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[0]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.05 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[1]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.09 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[2]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.12 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[3]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.15 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[5]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.15 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[6]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.12 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[7]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.09 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    sampleColor = inputTexture.sample(quadSampler, blurCoordinates[8]);
    distanceFromCentralColor = min(distance(centralColor, sampleColor) * distanceNormalizationFactor, 1.0);
    gaussianWeight = 0.05 * (1.0 - distanceFromCentralColor);
    gaussianWeightTotal += gaussianWeight;
    sum += sampleColor * gaussianWeight;
    
    const half4 outColor = sum / gaussianWeightTotal;
    outputTexture.write(outColor, grid);
}
