//
//  C7WhiteBalance.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

static float3 tintedRGB(float3 rgb, float tint) {
    if (tint == 0.0f) return rgb;
    const float3x3 toYIQ = float3x3(float3(0.299f, 0.587f, 0.114f), float3(0.596f, -0.274f, -0.322f), float3(0.212f, -0.523f, 0.311f));
    const float3x3 toRGB = float3x3(float3(1.0f, 0.956f, 0.621f), float3(1.0f, -0.272f, -0.647f), float3(1.0f, -1.105f, 1.702f));
    float3 yiq = toYIQ * rgb;
    const float shifted = yiq.b + tint * 0.05226f;
    // SDR 保持既有色偏边界；HDR 的原信号不压回单位色度范围。
    yiq.b = all(rgb >= 0.0f) && all(rgb <= 1.0f) ? clamp(shifted, -0.5226f, 0.5226f) : shifted;
    return toRGB * yiq;
}
static float3 warmRGB(float3 rgb) {
    const float3 warm = float3(0.93f, 0.54f, 0.0f);
    float3 result;
    for (uint i = 0; i < 3; i++) {
        const float v = rgb[i], w = warm[i];
        result[i] = v < 0.5f ? 2.0f * v * w : 1.0f + 2.0f * (1.0f - w) * (v - 1.0f);
    }
    return result;
}

kernel void C7WhiteBalance(texture2d<float, access::write> outputTexture [[texture(0)]],
                          texture2d<float, access::read> inputTexture [[texture(1)]],
                          constant float &temperature [[buffer(0)]],
                           constant float &tint [[buffer(1)]],
                           constant float &halfOutput [[buffer(2)]],
                          uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 color = inputTexture.read(grid);
    if (temperature == 5000.0f && tint == 0.0f) { outputTexture.write(color, grid); return; }
    if (color.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
    const float3 source = color.rgb / color.a;
    const float3 rgb = tintedRGB(source, tint / 100.0f);
    const float amount = temperature < 5000.0f ? 0.0004f * (temperature - 5000.0f) : 0.00006f * (temperature - 5000.0f);
    const float4 result = float4((rgb + (warmRGB(rgb) - rgb) * amount) * color.a, color.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
