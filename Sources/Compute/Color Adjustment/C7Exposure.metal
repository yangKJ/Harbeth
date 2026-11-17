//
//  C7Exposure.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

static float4 pointExposure(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 0.0f;
    if (value == 0.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    return float4(color.rgb * exp2(value), color.a);
}

kernel void C7Exposure(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float &parameter [[buffer(0)]],
                       constant float &halfOutput [[buffer(1)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = pointExposure(inputTexture.read(grid), parameter);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
