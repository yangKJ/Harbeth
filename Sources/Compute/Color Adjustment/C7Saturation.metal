//
//  C7Saturation.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

static float4 pointSaturation(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 1.0f;
    if (value == 1.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    const float gray = dot(color.rgb, float3(0.2125f, 0.7154f, 0.0721f));
    return float4(color.rgb + (float3(gray) - color.rgb) * (1.0f - value), color.a);
}

kernel void C7Saturation(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float &parameter [[buffer(0)]],
                       constant float &halfOutput [[buffer(1)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = pointSaturation(inputTexture.read(grid), parameter);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
