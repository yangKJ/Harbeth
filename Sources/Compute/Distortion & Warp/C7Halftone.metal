//
//  C7Halftone.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Halftone(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float *fractionalWidth [[buffer(0)]],
                       constant float4 *regionContext [[buffer(30)]],
                       constant float &halfOutput [[buffer(1)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    if (!isfinite(*fractionalWidth) || *fractionalWidth <= 0.0f) {
        const float2 uv = (float2(grid) + outputRegion.xy) / max(outputRegion.zw, float2(1.0f));
        const float2 local = all(inputRegion.zw == outputRegion.zw)
            ? float2(grid) + outputRegion.xy - inputRegion.xy : uv * inputRegion.zw - inputRegion.xy;
        const int2 point = clamp(int2(local), int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
        const float4 value = inputTexture.read(uint2(point));
        outputTexture.write(halfOutput > 0.5f ? float4(half4(value)) : value, grid);
        return;
    }
    const float fractionalWidthOfPixel = float(*fractionalWidth);
    const float aspectRatio = outputRegion.w / outputRegion.z;
    const float2 sampleDivisor = float2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
    
    const float2 textureCoordinate = (float2(grid) + outputRegion.xy) / outputRegion.zw;
    const float2 _mod = textureCoordinate - sampleDivisor * floor(textureCoordinate / sampleDivisor);
    const float2 samplePos = textureCoordinate - _mod + float2(0.5) * sampleDivisor;
    const float2 textureCoordinateToUse = float2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float2 adjustedSamplePos = float2(samplePos.x, (samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
    
    float2 clampedSamplePos = clamp(samplePos, 0.0, 1.0);
    const float2 localPixel = clampedSamplePos * inputRegion.zw - inputRegion.xy;
    const int2 safeCoord = clamp(int2(localPixel), int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    const float3 sampledColor = inputTexture.read(uint2(safeCoord)).rgb;
    const float3 luminanceWeighting = float3(0.2125, 0.7154, 0.0721);
    const float dotScaling = 1.0 - dot(float3(sampledColor), float3(luminanceWeighting));
    
    const float checkForPresenceWithinDot = 1.0 - step(distanceFromSamplePoint, (fractionalWidthOfPixel * 0.5) * dotScaling);
    const float4 outColor(float3(checkForPresenceWithinDot), 1.0f);
    
    outputTexture.write(halfOutput>0.5f?float4(half4(outColor)):outColor, grid);
}
