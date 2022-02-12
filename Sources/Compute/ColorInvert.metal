//
//  ColorInvert.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

// 1-rgb
kernel void ColorInvert(texture2d<half, access::write> outTexture [[texture(0)]],
                        texture2d<half, access::read> inTexture [[texture(1)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    
    const half4 outColor(1.0 - inColor.rgb, inColor.a);
    
    outTexture.write(outColor, grid);
}
