//
//  C7GaussianBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

// 理论知识
// https://juejin.cn/post/6944757638005686286

#include <metal_stdlib>
using namespace metal;

kernel void C7GaussianBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::sample> inputTexture [[texture(1)]],
                           constant float *blurRadius [[buffer(0)]],
                           uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 coordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half radius = half(*blurRadius) / 100.0h;
    
    // 高斯模糊卷积核
    const half3x3 matrix = half3x3({1.0, 2.0, 1.0},
                                   {2.0, 4.0, 2.0},
                                   {1.0, 2.0, 1.0});
    half4 sum = half4(0.0h);
    const half4 sample1 = inputTexture.sample(quadSampler, float2(coordinate.x - radius, coordinate.y - radius));
    const half4 sample2 = inputTexture.sample(quadSampler, float2(coordinate.x, coordinate.y - radius));
    const half4 sample3 = inputTexture.sample(quadSampler, float2(coordinate.x + radius, coordinate.y - radius));
    const half4 sample4 = inputTexture.sample(quadSampler, float2(coordinate.x - radius, coordinate.y));
    const half4 sample5 = inputTexture.sample(quadSampler, float2(coordinate.x, coordinate.y));
    const half4 sample6 = inputTexture.sample(quadSampler, float2(coordinate.x + radius, coordinate.y));
    const half4 sample7 = inputTexture.sample(quadSampler, float2(coordinate.x - radius, coordinate.y + radius));
    const half4 sample8 = inputTexture.sample(quadSampler, float2(coordinate.x, coordinate.y + radius));
    const half4 sample9 = inputTexture.sample(quadSampler, float2(coordinate.x + radius, coordinate.y + radius));
    
    sum = (sample1 * matrix[0][0] + sample2 * matrix[0][1] + sample3 * matrix[0][2] +
           sample4 * matrix[1][0] + sample5 * matrix[1][1] + sample6 * matrix[1][2] +
           sample7 * matrix[2][0] + sample8 * matrix[2][1] + sample9 * matrix[2][2]);
    
    const half4 outColor = sum / 16.0h;
    outputTexture.write(outColor, grid);
}
