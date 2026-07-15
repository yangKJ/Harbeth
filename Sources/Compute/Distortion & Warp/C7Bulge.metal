//
//  C7Bulge.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Bulge(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *centerPointerX [[buffer(0)]],
                    constant float *centerPointerY [[buffer(1)]],
                    constant float *radiusPointer [[buffer(2)]],
                    constant float *scalePointer [[buffer(3)]],
                    constant float4 *regionContext [[buffer(30)]],
                    uint2 grid [[thread_position_in_grid]]) {
    
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    int width = int(outputRegion.z);
    int height = int(outputRegion.w);
    uint2 pos = uint2(float2(grid) + outputRegion.xy);
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    
    const float2 center = float2(*centerPointerX, *centerPointerY);
    const float radius = float(*radiusPointer);
    const float scale = float(*scalePointer);
    const float aspectRatio = float(height) / float(width);
    
    const float2 inCoordinate = float2(float(pos.x) / float(width), float(pos.y) / float(height));
    float2 textureCoordinate = float2(inCoordinate.x, (inCoordinate.y - center.y) * aspectRatio + center.y);
    const float dist = distance(center, textureCoordinate);
    textureCoordinate = inCoordinate;
    
    if (dist < radius) {
        textureCoordinate -= center;
        float percent = 1.0 - (radius - dist) / radius * scale;
        percent = percent * percent;
        textureCoordinate = textureCoordinate * percent + center;
    }
    
    textureCoordinate = clamp(textureCoordinate, float2(0.0), float2(1.0));
    int2 samplePos = int2(textureCoordinate.x * float(width), textureCoordinate.y * float(height)) - int2(inputRegion.xy);
    samplePos = clamp(samplePos, int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    const half4 outColor = inputTexture.read(uint2(samplePos));
    
    outputTexture.write(outColor, grid);
}
