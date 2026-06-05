//
//  C7Sepia.metal
//  Harbeth
//
//  Created by Condy on 2022/2/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Sepia(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *intensity [[buffer(0)]],
                    uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4x4 matrix = half4x4(half4(0.3588h, 0.7044h, 0.1368h, 0.0h),
                                   half4(0.2990h, 0.5870h, 0.1140h, 0.0h),
                                   half4(0.2392h, 0.4696h, 0.0912h, 0.0h),
                                   half4(0.0000h, 0.0000h, 0.0000h, 1.0h));
    const half4 outColor = half(*intensity) * (inColor * matrix) + (1.0h - half(*intensity)) * inColor;
    
    outputTexture.write(outColor, grid);
}
