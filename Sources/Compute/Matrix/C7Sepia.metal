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
    
    const half4x4 matrix = half4x4({0.3588, 0.7044, 0.1368, 0.0},
                                   {0.2990, 0.5870, 0.1140, 0.0},
                                   {0.2392, 0.4696, 0.0912, 0.0},
                                   {0.0000, 0.0000, 0.0000, 1.0});
    const half4 outColor = half(*intensity) * (inColor * matrix) + (1.0h - half(*intensity)) * inColor;
    
    outputTexture.write(outColor, grid);
}
