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
                    uint2 grid [[thread_position_in_grid]]) {
    
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
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
    uint2 samplePos = uint2(textureCoordinate.x * float(width), textureCoordinate.y * float(height));
    samplePos = uint2(clamp(int(samplePos.x), 0, width - 1), clamp(int(samplePos.y), 0, height - 1));
    const half4 outColor = inputTexture.read(samplePos);
    
    outputTexture.write(outColor, grid);
}
