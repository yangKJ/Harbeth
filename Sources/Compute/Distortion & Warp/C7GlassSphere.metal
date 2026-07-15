//
//  C7GlassSphere.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7GlassSphere(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *radius [[buffer(0)]],
                          constant float *refractiveIndex [[buffer(1)]],
                          constant float *aspectRatio [[buffer(2)]],
                          constant float *centerX [[buffer(3)]],
                          constant float *centerY [[buffer(4)]],
                          constant float4 *regionContext [[buffer(30)]],
                          uint2 grid [[thread_position_in_grid]]) {
    
    const float _aspectRatio = float(*aspectRatio);
    const float _radius = float(*radius);
    const float2 center = float2(*centerX, *centerY);
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float2 textureCoord = (float2(grid) + outputRegion.xy) / outputRegion.zw;
    
    const float2 textureCoordinate = float2(textureCoord.x, (textureCoord.y * _aspectRatio + 0.5 - 0.5 * _aspectRatio));
    float distanceFromCenter = distance(center, textureCoordinate);
    float checkForPresenceWithinSphere = step(distanceFromCenter, _radius);
    
    distanceFromCenter = distanceFromCenter / _radius;
    
    float normalizedDepth = _radius * sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    float3 sphereNormal = normalize(float3(textureCoordinate - center, normalizedDepth));
    
    float3 refractedVector = 2.0 * refract(float3(0.0, 0.0, -1.0), sphereNormal, float(*refractiveIndex));
    refractedVector.xy = -refractedVector.xy;
    
    float2 sampleCoord = (refractedVector.xy + 1.0) * 0.5;
    sampleCoord = clamp(sampleCoord, 0.0, 1.0);
    const int2 texCoord = int2(sampleCoord * inputRegion.zw - inputRegion.xy);
    const int2 safeCoord = clamp(texCoord, int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    half3 finalSphereColor = half3(inputTexture.read(uint2(safeCoord)).rgb);
    
    // Grazing angle lighting
    const float3 ambientLightPosition = float3(0.0, 0.0, 1.0);
    float lightingIntensity = 2.5 * (1.0 - pow(clamp(dot(ambientLightPosition, sphereNormal), 0.0, 1.0), 0.25));
    finalSphereColor += lightingIntensity;
    
    // Specular lighting
    const float3 lightPosition = float3(-0.5, 0.5, 1.0);
    lightingIntensity = clamp(dot(normalize(lightPosition), sphereNormal), 0.0, 1.0);
    lightingIntensity = pow(lightingIntensity, 15.0);
    finalSphereColor += half3(0.8, 0.8, 0.8) * half(lightingIntensity);
    
    const half4 outColor = half4(finalSphereColor, 1.0h) * half(checkForPresenceWithinSphere);
    outputTexture.write(outColor, grid);
}
