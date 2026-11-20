//
//  C7Opacity.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

static float4 pointOpacity(float4 color, float parameter) {
    const float value = isfinite(parameter) ? clamp(parameter, 0.0f, 1.0f) : 1.0f;
    if (value == 1.0f) return color;
    if (value == 0.0f || color.a <= 0.0f) return float4(0);
    return color * value;
}

kernel void C7Opacity(texture2d<float, access::write> outputTexture [[texture(0)]],
                      texture2d<float, access::read> inputTexture [[texture(1)]],
                      constant float &parameter [[buffer(0)]],
                      constant float &halfOutput [[buffer(1)]],
                      uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = pointOpacity(inputTexture.read(grid), parameter);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
