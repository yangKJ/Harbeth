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
                       uint2 grid [[thread_position_in_grid]]) {
    
    const float fractionalWidthOfPixel = float(*fractionalWidth);
    const float aspectRatio = float(inputTexture.get_height()) / float(inputTexture.get_width());
    const float2 sampleDivisor = float2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 _mod = textureCoordinate - sampleDivisor * floor(textureCoordinate / sampleDivisor);
    const float2 samplePos = textureCoordinate - _mod + 0.5 * sampleDivisor;
    const float2 textureCoordinateToUse = float2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float2 adjustedSamplePos = float2(samplePos.x, (samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
    const float checkForPresenceWithinDot = step(distanceFromSamplePoint, (fractionalWidthOfPixel * 0.5) * float(*dotScaling));
    float2 clampedSamplePos = clamp(samplePos, 0.0, 1.0);
    uint2 texCoord = uint2(clampedSamplePos * float2(inputTexture.get_width(), inputTexture.get_height()));
    half4 outColor = inputTexture.read(texCoord);
    outColor = half4(outColor.rgb * half(checkForPresenceWithinDot), outColor.a);
    
    outputTexture.write(outColor, grid);
}
