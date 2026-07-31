//
//  C7ColorMatrix4x4.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorMatrix4x4(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *intensity [[buffer(0)]],
                             constant float4 &offset [[buffer(1)]],
                             constant float4x4 *colorMatrix [[buffer(2)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half r = inColor.r;
    const half g = inColor.g;
    const half b = inColor.b;
    const half a = inColor.a;
    
    const half4x4 matrix = half4x4(*colorMatrix);
    const half red   = r * matrix[0][0] + g * matrix[0][1] + b * matrix[0][2] + a * matrix[0][3] + half(offset.r);
    const half green = r * matrix[1][0] + g * matrix[1][1] + b * matrix[1][2] + a * matrix[1][3] + half(offset.g);
    const half blue  = r * matrix[2][0] + g * matrix[2][1] + b * matrix[2][2] + a * matrix[2][3] + half(offset.b);
    const half alpha = r * matrix[3][0] + g * matrix[3][1] + b * matrix[3][2] + a * matrix[3][3] + half(offset.a);
    
    const half4 outColor = half4(red, green, blue, alpha);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
