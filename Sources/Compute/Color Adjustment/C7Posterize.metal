//
//  C7Posterize.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Posterize(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float &parameter [[buffer(0)]],
                       constant float &halfOutput [[buffer(1)]],
                       uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 color = inputTexture.read(grid);
    const float levels = isfinite(parameter) && parameter > 0.0f ? parameter : 10.0f;
    if (color.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
    const float3 straight = color.rgb / color.a;
    const float4 result = float4(floor(straight * levels + 0.5f) / levels * color.a, color.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
