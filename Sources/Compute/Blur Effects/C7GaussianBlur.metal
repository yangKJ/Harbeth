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

kernel void C7GaussianBlur(texture2d<float, access::write> outputTexture [[texture(0)]],
                           texture2d<float, access::read> inputTexture [[texture(1)]],
                           constant float *blurRadius [[buffer(0)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float2 extent = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 base = float2(grid);
    if (inputTexture.get_width() != outputTexture.get_width() || inputTexture.get_height() != outputTexture.get_height()) {
        base = precise::divide(float2(grid), float2(outputTexture.get_width(), outputTexture.get_height())) * extent;
    }
    if (!isfinite(*blurRadius) || *blurRadius <= 0.0f) {
        outputTexture.write(inputTexture.read(uint2(clamp(base, float2(0), extent - 1))), grid); return;
    }
    const float spacing = precise::divide(*blurRadius, 100.0f);
    const float weights[3] = {1,2,1};
    float4 result = 0;
    for (int y = -1; y <= 1; ++y) for (int x = -1; x <= 1; ++x) {
        uint2 point = uint2(clamp(base + float2(x,y) * spacing * extent, float2(0), extent - 1));
        result += inputTexture.read(point) * (weights[x+1] * weights[y+1] / 16.0f);
    }
    outputTexture.write(result, grid);
}
