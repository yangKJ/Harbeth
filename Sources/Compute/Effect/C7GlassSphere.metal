//
//  C7GlassSphere.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7GlassSphere(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::sample> inputTexture [[texture(1)]],
                          constant float *radius [[buffer(0)]],
                          constant float *refractiveIndex [[buffer(1)]],
                          constant float *aspectRatio [[buffer(2)]],
                          constant float *centerX [[buffer(3)]],
                          constant float *centerY [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float _aspectRatio = float(*aspectRatio);
    const float _radius = float(*radius);
    const float2 center = float2(*centerX, *centerY);
    const float2 textureCoord = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const float2 textureCoordinate = float2(textureCoord.x, (textureCoord.y * _aspectRatio + 0.5 - 0.5 * _aspectRatio));
    float distanceFromCenter = distance(center, textureCoordinate);
    float checkForPresenceWithinSphere = step(distanceFromCenter, _radius);
    
    distanceFromCenter = distanceFromCenter / _radius;
    
    float normalizedDepth = _radius * sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    float3 sphereNormal = normalize(float3(textureCoordinate - center, normalizedDepth));
    
    float3 refractedVector = 2.0 * refract(float3(0.0, 0.0, -1.0), sphereNormal, float(*refractiveIndex));
    refractedVector.xy = -refractedVector.xy;
    
    half3 finalSphereColor = half3(inputTexture.sample(quadSampler, (refractedVector.xy + 1.0) * 0.5).rgb);
    
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
