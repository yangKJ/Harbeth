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
    const float2 textureCoordinate = float2(grid) / float2(outputTexture.get_width(), outputTexture.get_height());
    const half radius = half(*blurRadius) / 100.0h;
    const float x = textureCoordinate.x;
    const float y = textureCoordinate.y;
    
    // 高斯模糊卷积核
    const half3x3 matrix = half3x3({1.0, 2.0, 1.0}, {2.0, 4.0, 2.0}, {1.0, 2.0, 1.0});
    half4 result = half4(0.0h);
    for (int i = 0; i < 9; i++) {
        int a = i % 3; int b = i / 3;
        const half4 sample = inputTexture.sample(quadSampler, float2(x + (a-1) * radius, y + (b-1) * radius));
        result += sample * matrix[a][b];
    }
    
    const half4 outColor = result / 16.0h;
    outputTexture.write(outColor, grid);
}
