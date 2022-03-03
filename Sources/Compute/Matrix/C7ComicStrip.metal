//
//  C7ComicStrip.metal
//  Harbeth
//
//  Created by Condy on 2022/3/3.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ComicStrip(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half r = inColor.r;
    const half g = inColor.g;
    const half b = inColor.b;
    
    const half R = half(abs(g - b + g + r) * r);
    const half G = half(abs(b - g + b + r) * r);
    const half B = half(abs(b - g + b + r) * g);
    
    const half4 outColor = half4(R, G, B, inColor.a);
    
    outputTexture.write(outColor, grid);
}
