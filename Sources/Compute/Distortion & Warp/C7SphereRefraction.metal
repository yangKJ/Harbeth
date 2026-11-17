//
//  C7SphereRefraction.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SphereRefraction(texture2d<float, access::write> outputTexture [[texture(0)]],
                               texture2d<float, access::read> inputTexture [[texture(1)]],
                               constant float *radius [[buffer(0)]],
                               constant float *refractiveIndex [[buffer(1)]],
                               constant float *aspectRatio [[buffer(2)]],
                               constant float *centerX [[buffer(3)]],
                               constant float *centerY [[buffer(4)]],
                               constant float &halfOutput [[buffer(5)]],
                               uint2 grid [[thread_position_in_grid]]) {
    
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float _aspectRatio = float(*aspectRatio);
    const float _radius = float(*radius);
    const float2 center = float2(*centerX, *centerY);
    const float2 textureCoord = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const float2 textureCoordinate = float2(textureCoord.x, (textureCoord.y * _aspectRatio + 0.5 - 0.5 * _aspectRatio));
    float distanceFromCenter = distance(center, textureCoordinate);
    if (_radius <= 0.0f || distanceFromCenter > _radius) { outputTexture.write(float4(0), grid); return; }
    
    distanceFromCenter = distanceFromCenter / _radius;
    
    float normalizedDepth = _radius * sqrt(max(0.0f, 1.0f - distanceFromCenter * distanceFromCenter));
    float3 sphereNormal = normalize(float3(textureCoordinate - center, normalizedDepth));
    
    float3 refractedVector = refract(float3(0.0, 0.0, -1.0), sphereNormal, (*refractiveIndex));
    
    float2 sampleCoord = (refractedVector.xy + 1.0) * 0.5;
    sampleCoord = clamp(sampleCoord, 0.0, 1.0);
    const int2 size = int2(inputTexture.get_width(), inputTexture.get_height());
    const uint2 texCoord = uint2(clamp(int2(sampleCoord * float2(size)), int2(0), size - 1));
    const float4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(halfOutput > 0.5f ? float4(half4(outColor)) : outColor, grid);
}
