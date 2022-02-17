//
//  C7Brightness.metal
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Brightness(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         device float *brightness [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor = half4(inColor.rgb + half3(*brightness), inColor.a);
    
    outputTexture.write(outColor, grid);
}
