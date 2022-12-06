//
//  C7SolidColor.metal
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SolidColor(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         device float4 *colorVector [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 color = half4(*colorVector);
    
    const half4 outColor = half4(color[0], color[1], color[2], color[3]);
    
    outputTexture.write(outColor, grid);
}
