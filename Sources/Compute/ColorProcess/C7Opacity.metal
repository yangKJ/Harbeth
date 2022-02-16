//
//  C7Opacity.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Opacity(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      device float *opacity [[buffer(0)]],
                      uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor = half4(inColor.rgb, half(*opacity) * inColor.a);
    
    outputTexture.write(outColor, grid);
}
