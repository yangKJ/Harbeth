//
//  C7Pow.metal
//  Harbeth
//
//  Created by Condy on 2023/7/28.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Pow(texture2d<half, access::write> outputTexture [[texture(0)]],
                  texture2d<half, access::read> inputTexture [[texture(1)]],
                  constant float *value [[buffer(0)]],
                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor = half4(pow(inColor.rgb, (*value)), 1.0);
    
    outputTexture.write(outColor, grid);
}
