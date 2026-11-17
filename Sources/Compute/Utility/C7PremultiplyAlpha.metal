//
//  C7PremultiplyAlpha.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7PremultiplyAlpha(texture2d<float, access::write> outputTexture [[texture(0)]],
                               texture2d<float, access::read> inputTexture [[texture(1)]],
                               constant float &halfOutput [[buffer(0)]],
                               uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    const float4 color = inputTexture.read(grid);
    const float4 result = color.a <= 0.0f ? float4(0) : float4(color.rgb * color.a, color.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
