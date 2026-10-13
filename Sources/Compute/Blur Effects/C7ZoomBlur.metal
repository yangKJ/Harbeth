//
//  C7ZoomBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ZoomBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *blurCenterX [[buffer(0)]],
                       constant float *blurCenterY [[buffer(1)]],
                       constant float *radius [[buffer(2)]],
                       constant float *mappingContext [[buffer(30)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }

    const float2 inputOrigin = float2(mappingContext[0], mappingContext[1]);
    const float2 outputOrigin = float2(mappingContext[4], mappingContext[5]);
    const float2 logicalSize = max(float2(mappingContext[6], mappingContext[7]), float2(1.0f));
    const float2 globalPixel = outputOrigin + float2(grid);
    const int2 maximum = int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1);
    const int2 inputPixel = clamp(int2(round(globalPixel - inputOrigin)), int2(0), maximum);
    const half4 original = inputTexture.read(uint2(inputPixel));
    if (*radius == 0.0f) {
        outputTexture.write(original, grid);
        return;
    }

    const float2 center = float2(*blurCenterX, *blurCenterY) * logicalSize;
    const float2 step = (center - (globalPixel + 0.5f)) * (*radius / 100.0f);
    const float weights[4] = {0.15f, 0.12f, 0.09f, 0.05f};
    float4 color = float4(original) * 0.18f;
    for (int tap = 1; tap <= 4; tap++) {
        // 相对偏移独立取整，正负采样成对；有符号裁边避免负坐标转换成无符号数。
        const int2 offset = int2(round(clamp(step * float(tap), -logicalSize, logicalSize)));
        const uint2 forward = uint2(clamp(inputPixel + offset, int2(0), maximum));
        const uint2 backward = uint2(clamp(inputPixel - offset, int2(0), maximum));
        color += (float4(inputTexture.read(forward)) + float4(inputTexture.read(backward))) * weights[tap - 1];
    }
    outputTexture.write(half4(color), grid);
}
