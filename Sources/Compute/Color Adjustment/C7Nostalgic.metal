//
//  C7Nostalgic.metal
//  Harbeth
//
//  Created by Condy on 2022/3/3.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Nostalgic(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *intensity [[buffer(0)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4x4 matrix = half4x4(half4(0.272h, 0.534h, 0.131h, 0.0h),
                                   half4(0.349h, 0.686h, 0.168h, 0.0h),
                                   half4(0.393h, 0.769h, 0.189h, 0.0h),
                                   half4(0.000h, 0.000h, 0.000h, 1.0h));
    const half4 outColor = half(*intensity) * (inColor * matrix) + (1.0h - half(*intensity)) * inColor;
    
    outputTexture.write(outColor, grid);
}
