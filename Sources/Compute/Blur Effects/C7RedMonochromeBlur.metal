//
//  C7RedMonochromeBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7RedMonochromeBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                constant float *pixelRadius [[buffer(0)]],
                                constant float *vertical [[buffer(1)]],
                                constant float *horizontal [[buffer(2)]],
                                uint2 grid [[thread_position_in_grid]]) {
    
    const int radius = int(abs(*pixelRadius));
    const float w = float(inputTexture.get_width());
    const float h = float(inputTexture.get_height());
    half maxValue = half(0.0h);
    
    if ((*vertical) && (*horizontal)) {
        for (int i = -radius; i <= radius; ++i) {
            float2 coordinate = float2(float(grid.x + i) / outputTexture.get_width(), float(grid.y + i) / outputTexture.get_height());
            coordinate = clamp(coordinate, 0.0, 1.0);
            uint2 texCoord = uint2(coordinate * float2(w, h));
            const half intensity = inputTexture.read(texCoord).r;
            maxValue = max(maxValue, intensity);
        }
    } else if (*vertical) {
        for (int i = -radius; i <= radius; ++i) {
            float2 coordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y + i) / outputTexture.get_height());
            coordinate = clamp(coordinate, 0.0, 1.0);
            uint2 texCoord = uint2(coordinate * float2(w, h));
            const half intensity = inputTexture.read(texCoord).r;
            maxValue = max(maxValue, intensity);
        }
    } else if (*horizontal) {
        for (int i = -radius; i <= radius; ++i) {
            float2 coordinate = float2(float(grid.x + i) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
            coordinate = clamp(coordinate, 0.0, 1.0);
            uint2 texCoord = uint2(coordinate * float2(w, h));
            const half intensity = inputTexture.read(texCoord).r;
            maxValue = max(maxValue, intensity);
        }
    }
    const half4 outColor = half4(half3(maxValue), 1.0h);
    
    outputTexture.write(outColor, grid);
}
