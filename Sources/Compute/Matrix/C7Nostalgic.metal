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
    
    const half4x4 matrix = half4x4({0.272, 0.534, 0.131, 0.0},
                                   {0.349, 0.686, 0.168, 0.0},
                                   {0.393, 0.769, 0.189, 0.0},
                                   {0.000, 0.000, 0.000, 1.0});
    const half4 outColor = half(*intensity) * (inColor * matrix) + (1.0h - half(*intensity)) * inColor;
    
    outputTexture.write(outColor, grid);
}
