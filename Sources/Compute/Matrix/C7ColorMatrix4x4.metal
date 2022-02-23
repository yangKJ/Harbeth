//
//  C7ColorMatrix4x4.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorMatrix4x4(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::sample> inputTexture [[texture(1)]],
                             constant float *intensity [[buffer(0)]],
                             constant float4x4 *colorMatrix [[buffer(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    half4 outColor = inColor * half4x4(*colorMatrix);
    outColor = half(*intensity) * outColor + (1.0 - half(*intensity)) * inColor;
    
    outputTexture.write(outColor, grid);
}
