//
//  C7Warmth.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Warmth(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float &parameter [[buffer(0)]],
                       constant float &halfOutput [[buffer(1)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 color = inputTexture.read(grid);
    const float value = isfinite(parameter) ? parameter : 0.0f;
    if (value == 0.0f) { outputTexture.write(color, grid); return; }
    if (color.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
    const float3 delta = value > 0.0f ? float3(0.3f, 0.2f, -0.2f) * value : float3(-0.2f, -0.1f, 0.3f) * -value;
    const float4 result = float4(color.rgb + delta * color.a, color.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
