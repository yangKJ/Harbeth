//
//  C7CircleBlur.metal
//  Harbeth
//
//  Created by Condy on 2023/8/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CircleBlur(texture2d<float, access::write> outputTexture [[texture(0)]],
                         texture2d<float, access::read> inputTexture [[texture(1)]],
                         constant float *blurRadius [[buffer(0)]],
                         constant float *sampleCountPointer [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float2 extent = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 base = float2(grid);
    if (inputTexture.get_width() != outputTexture.get_width() || inputTexture.get_height() != outputTexture.get_height()) {
        base = precise::divide(float2(grid), float2(outputTexture.get_width(), outputTexture.get_height())) * extent;
    }
    const uint2 center = uint2(clamp(base, float2(0), extent - 1));
    // 保留旧 half 参数能表示的有效样本范围，不再让非法值进入整数转换。
    if (!isfinite(*blurRadius) || !isfinite(*sampleCountPointer) || *blurRadius <= 0 ||
        *sampleCountPointer < 1 || *sampleCountPointer > 65504) {
        outputTexture.write(inputTexture.read(center), grid);
        return;
    }
    const float radius = float(half(*blurRadius) / 100.0h);
    if (!isfinite(radius)) { outputTexture.write(inputTexture.read(center), grid); return; }
    const uint sampleCount = uint(*sampleCountPointer);
    const float inverseCount = precise::divide(1.0f, float(sampleCount));
    float4 result = 0;
    for (uint i = 0; i < sampleCount; ++i) {
        float angle = float(i) * inverseCount * M_PI_F * 2;
        float2 position = base + float2(cos(angle), sin(angle)) * radius * extent;
        uint2 pixel = uint2(clamp(position, float2(0), extent - 1));
        result += inputTexture.read(pixel) * inverseCount;
    }
    outputTexture.write(result, grid);
}
