//
//  C7Contrast.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Contrast(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *contrast [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 zero = half3(0.5h);
    const half4 outColor = half4((zero + (inColor.rgb - zero) * (*contrast)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
