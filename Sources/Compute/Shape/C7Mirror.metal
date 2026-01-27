//
//  C7Mirror.metal
//  Harbeth
//
//  Created by Condy on 2025/7/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Mirror(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     uint2 grid [[thread_position_in_grid]]) {
    uint2 mirroredGid = uint2(inputTexture.get_width() - 1 - grid.x, grid.y);
    const half4 outColor = inputTexture.read(mirroredGid);
    outputTexture.write(outColor, grid);
}
