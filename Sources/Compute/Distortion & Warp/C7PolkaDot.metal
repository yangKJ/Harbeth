//
//  C7PolkaDot.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7PolkaDot(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *fractionalWidth [[buffer(0)]],
                       constant float *dotScaling [[buffer(1)]],
                       constant float4 *regionContext [[buffer(30)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float fractionalWidthOfPixel = float(*fractionalWidth);
    const float aspectRatio = outputRegion.w / outputRegion.z;
    const float2 sampleDivisor = float2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
    const float2 textureCoordinate = (float2(grid) + outputRegion.xy) / outputRegion.zw;
    const float2 _mod = textureCoordinate - sampleDivisor * floor(textureCoordinate / sampleDivisor);
    const float2 samplePos = textureCoordinate - _mod + 0.5 * sampleDivisor;
    const float2 textureCoordinateToUse = float2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float2 adjustedSamplePos = float2(samplePos.x, (samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
    const float checkForPresenceWithinDot = step(distanceFromSamplePoint, (fractionalWidthOfPixel * 0.5) * float(*dotScaling));
    float2 clampedSamplePos = clamp(samplePos, 0.0, 1.0);
    const float2 localPixel = clampedSamplePos * inputRegion.zw - inputRegion.xy;
    const int2 safeCoord = clamp(int2(localPixel), int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    half4 outColor = inputTexture.read(uint2(safeCoord));
    outColor = half4(outColor.rgb * half(checkForPresenceWithinDot), outColor.a);
    
    outputTexture.write(outColor, grid);
}
