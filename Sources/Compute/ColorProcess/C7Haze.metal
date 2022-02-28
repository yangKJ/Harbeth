//
//  C7Haze.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Haze(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::read> inputTexture [[texture(1)]],
                   constant float *hazeDistance [[buffer(0)]],
                   constant float *slope [[buffer(1)]],
                   uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 white = half4(1.0h);
    const half dd = half(grid.y) / half(inputTexture.get_height()) * half(*slope) + half(*hazeDistance);
    const half4 outColor = half4((inColor - dd * white) / (1.0h - dd));
    
    outputTexture.write(outColor, grid);
}

