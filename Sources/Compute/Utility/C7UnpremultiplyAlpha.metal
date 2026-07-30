//
//  C7UnpremultiplyAlpha.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7UnpremultiplyAlpha(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    float4 color = float4(inputTexture.read(grid));
    if (color.a > 0.0001f) {
        color.rgb /= color.a;
    } else {
        color.rgb = float3(0.0f);
    }
    outputTexture.write(half4(color), grid);
}
