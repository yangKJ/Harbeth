//
//  C7PremultiplyAlpha.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7PremultiplyAlpha(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> inputTexture [[texture(1)]],
                               uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    half4 color = inputTexture.read(grid);
    color.rgb *= color.a;
    outputTexture.write(color, grid);
}
