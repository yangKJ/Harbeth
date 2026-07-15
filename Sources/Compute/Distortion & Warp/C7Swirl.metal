//
//  C7Swirl.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Swirl(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *centerPointerX [[buffer(0)]],
                    constant float *centerPointerY [[buffer(1)]],
                    constant float *radiusPointer [[buffer(2)]],
                    constant float *anglePointer [[buffer(3)]],
                    constant float4 *regionContext [[buffer(30)]],
                    uint2 grid [[thread_position_in_grid]]) {
    
    const float2 center = float2(*centerPointerX, *centerPointerY);
    const float radius = float(*radiusPointer);
    const float angle = float(*anglePointer);
    
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    float2 textureCoordinate = (float2(grid) + outputRegion.xy) / outputRegion.zw;
    const float dist = distance(center, textureCoordinate);
    
    if (dist < radius) {
        textureCoordinate -= center;
        const float percent = (radius - dist) / radius;
        const float theta = percent * percent * angle * 8.0;
        const float s = sin(theta);
        const float c = cos(theta);
        textureCoordinate = float2(dot(textureCoordinate, float2(c, -s)), dot(textureCoordinate, float2(s, c)));
        textureCoordinate += center;
    }
    
    float2 clampedCoord = clamp(textureCoordinate, 0.0, 1.0);
    const int2 texCoord = int2(clampedCoord * inputRegion.zw - inputRegion.xy);
    const int2 safeCoord = clamp(texCoord, int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    const half4 outColor = inputTexture.read(uint2(safeCoord));
    
    outputTexture.write(outColor, grid);
}
