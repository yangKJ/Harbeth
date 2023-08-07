//
//  C7Halftone.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Halftone(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::sample> inputTexture [[texture(1)]],
                       constant float *fractionalWidth [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float fractionalWidthOfPixel = float(*fractionalWidth);
    const float aspectRatio = float(inputTexture.get_height()) / float(inputTexture.get_width());
    const float2 sampleDivisor = float2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
    
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 _mod = textureCoordinate - sampleDivisor * floor(textureCoordinate / sampleDivisor);
    const float2 samplePos = textureCoordinate - _mod + float2(0.5) * sampleDivisor;
    const float2 textureCoordinateToUse = float2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float2 adjustedSamplePos = float2(samplePos.x, (samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
    
    const half3 sampledColor = inputTexture.sample(quadSampler, samplePos).rgb;
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const float dotScaling = 1.0 - dot(float3(sampledColor), float3(luminanceWeighting));
    
    const half checkForPresenceWithinDot = 1.0 - step(distanceFromSamplePoint, (fractionalWidthOfPixel * 0.5) * dotScaling);
    const half4 outColor(half3(checkForPresenceWithinDot), 1.0h);
    
    outputTexture.write(outColor, grid);
}
