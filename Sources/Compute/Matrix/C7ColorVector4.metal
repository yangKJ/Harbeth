//
//  C7ColorVector4.metal
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorVector4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float4 *vector [[buffer(0)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor = inColor + half4(*vector);
    
    outputTexture.write(outColor, grid);
}
