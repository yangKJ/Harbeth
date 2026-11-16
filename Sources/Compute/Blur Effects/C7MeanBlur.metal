//
//  C7MeanBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

// 均值模糊原理其实很简单通过多个纹理叠加，每个纹理偏移量设置不同达到一点重影效果来实现模糊
kernel void C7MeanBlur(texture2d<float, access::write> outputTexture [[texture(0)]],
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
    const float2 offset = precise::divide(*blurRadius, 100.0f) * extent;
    float4 result = 0;
    for (int y = -1; y <= 1; y += 2) for (int x = -1; x <= 1; x += 2) {
        uint2 point = uint2(clamp(base + float2(x,y) * offset, float2(0), extent - 1));
        result += inputTexture.read(point) * 0.25f;
    }
    outputTexture.write(result, grid);
}
