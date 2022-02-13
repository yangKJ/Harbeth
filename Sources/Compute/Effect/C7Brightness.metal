//
//  C7Brightness.metal
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Brightness(texture2d<half, access::write> outTexture [[texture(0)]],
                         texture2d<half, access::read> inTexture [[texture(1)]],
                         device float *brightness [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    
    const half4 outColor(inColor.rgb + half3(*brightness), inColor.a);
    
    outTexture.write(outColor, grid);
}
