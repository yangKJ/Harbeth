//
//  C7RedMonochromeBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7RedMonochromeBlur(texture2d<float, access::write> outputTexture [[texture(0)]],
                                texture2d<float, access::read> inputTexture [[texture(1)]],
                                constant float *pixelRadius [[buffer(0)]],
                                constant float *vertical [[buffer(1)]],
                                constant float *horizontal [[buffer(2)]],
                                uint2 grid [[thread_position_in_grid]]) {
    
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float2 sourceSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    const bool sameSize = all(sourceSize == outputSize);
    const float safeRadius = isfinite(*pixelRadius) ? min(abs(*pixelRadius), max(outputSize.x, outputSize.y)) : 0;
    const int radius = int(safeRadius);
    float maxValue = 0;
    if (*vertical || *horizontal) {
        const float2 axis = float2(*horizontal != 0 ? 1 : 0, *vertical != 0 ? 1 : 0);
        for (int i = -radius; i <= radius; ++i) {
            float2 position = float2(grid) + float(i) * axis;
            if (!sameSize) position = precise::divide(position, outputSize) * sourceSize;
            uint2 sample = uint2(clamp(position, float2(0), sourceSize - 1));
            maxValue = max(maxValue, inputTexture.read(sample).r);
        }
    }
    outputTexture.write(float4(float3(maxValue), 1), grid);
}
