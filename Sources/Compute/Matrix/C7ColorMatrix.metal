//
//  C7ColorMatrix.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorMatrix(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::sample> inputTexture [[texture(1)]],
                          constant float *intensity [[buffer(0)]],
                          constant float *m11 [[buffer(1)]],
                          constant float *m12 [[buffer(2)]],
                          constant float *m13 [[buffer(3)]],
                          constant float *m14 [[buffer(4)]],
                          constant float *m21 [[buffer(5)]],
                          constant float *m22 [[buffer(6)]],
                          constant float *m23 [[buffer(7)]],
                          constant float *m24 [[buffer(8)]],
                          constant float *m31 [[buffer(9)]],
                          constant float *m32 [[buffer(10)]],
                          constant float *m33 [[buffer(11)]],
                          constant float *m34 [[buffer(12)]],
                          constant float *m41 [[buffer(13)]],
                          constant float *m42 [[buffer(14)]],
                          constant float *m43 [[buffer(15)]],
                          constant float *m44 [[buffer(16)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4x4 matrix = half4x4({*m11, *m12, *m13, *m14},
                                   {*m21, *m22, *m23, *m24},
                                   {*m31, *m32, *m33, *m34},
                                   {*m41, *m42, *m43, *m44});
    half4 outColor = inColor * matrix;
    outColor = half(*intensity) * outColor + (1.0 - half(*intensity)) * inColor;
    
    outputTexture.write(outColor, grid);
}
