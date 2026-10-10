//
//  C7LevelsAdjustment.metal
//  Harbeth
//
//  Created by Condy on 2026/10/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LevelsAdjustment(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float3 &inputBlack [[buffer(0)]],
                              constant float3 &gamma [[buffer(1)]],
                              constant float3 &inputWhite [[buffer(2)]],
                              constant float3 &outputBlack [[buffer(3)]],
                              constant float3 &outputWhite [[buffer(4)]],
                              uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const half4 input = inputTexture.read(grid);
    const float alpha = float(input.a);
    if (alpha <= 0) { outputTexture.write(half4(0), grid); return; }
    const float3 color = float3(input.rgb) / alpha;
    const float3 fraction = clamp((color - inputBlack) / (inputWhite - inputBlack), 0.0f, 1.0f);
    const float3 adjusted = mix(outputBlack, outputWhite, pow(fraction, 1.0f / gamma));
    outputTexture.write(half4(half3(adjusted * alpha), input.a), grid);
}
