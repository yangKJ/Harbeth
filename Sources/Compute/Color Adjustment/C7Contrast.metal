//
//  C7Contrast.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

static float4 pointContrast(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 1.0f;
    if (value == 1.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    const float3 middle = float3(0.5f * color.a);
    return float4(middle + (color.rgb - middle) * value, color.a);
}

kernel void C7Contrast(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float &parameter [[buffer(0)]],
                       constant float &halfOutput [[buffer(1)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 result = pointContrast(inputTexture.read(grid), parameter);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
