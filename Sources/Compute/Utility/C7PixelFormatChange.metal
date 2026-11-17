//
//  C7PixelFormatChange.metal
//  Harbeth
//
//  Created by Condy on 2026/6/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7PixelFormatChange(texture2d<float, access::write> outputTexture [[texture(0)]],
                                texture2d<float, access::read> inputTexture [[texture(1)]],
                                constant float &halfOutput [[buffer(0)]],
                                uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    const float4 color = inputTexture.read(grid);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(color)) : color, grid);
}