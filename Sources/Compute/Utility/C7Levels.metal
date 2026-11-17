//
//  C7Levels.metal
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LevelsFilter(texture2d<float, access::write> outputTexture [[texture(0)]],
                              texture2d<float, access::read> inputTexture [[texture(1)]],
                              constant float3 &inputBlack [[buffer(0)]],
                              constant float3 &gamma [[buffer(1)]],
                              constant float3 &inputWhite [[buffer(2)]],
                              constant float3 &outputBlack [[buffer(3)]],
                              constant float3 &outputWhite [[buffer(4)]],
                              constant float &halfOutput [[buffer(5)]],
                              uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 input = inputTexture.read(grid);
    if (input.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
    const float3 color = input.rgb / input.a;
    const float3 fraction = clamp((color - inputBlack) / (inputWhite - inputBlack), 0.0f, 1.0f);
    const float3 adjusted = outputBlack + (outputWhite - outputBlack) * pow(fraction, 1.0f / gamma);
    const float4 result = float4(adjusted * input.a, input.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
