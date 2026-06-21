//
//  C7ForceOpaqueAlpha.metal
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ForceOpaqueAlpha(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> inputTexture [[texture(1)]],
                               uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    half4 color = inputTexture.read(grid);
    color.a = 1.0h;
    outputTexture.write(color, grid);
}
