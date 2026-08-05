//
//  C7Palettize.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Palettize(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float4 *palette [[buffer(0)]],
                        constant int *paletteCountPointer [[buffer(1)]],
                        constant float *intensityPointer [[buffer(2)]],
                        uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }

    const half4 input = inputTexture.read(grid);
    const float alpha = float(input.a);
    if (alpha <= 0.0f) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }

    const int paletteCount = clamp(*paletteCountPointer, 1, 32);
    const float3 straightInput = clamp(float3(input.rgb) / alpha, 0.0f, 1.0f);
    float3 nearest = palette[0].rgb;
    float3 difference = straightInput - nearest;
    float nearestDistance = dot(difference, difference);

    for (int index = 1; index < paletteCount; ++index) {
        const float3 candidate = palette[index].rgb;
        difference = straightInput - candidate;
        const float candidateDistance = dot(difference, difference);
        if (candidateDistance < nearestDistance) {
            nearest = candidate;
            nearestDistance = candidateDistance;
        }
    }

    const float intensity = clamp(*intensityPointer, 0.0f, 1.0f);
    const float3 straightOutput = mix(straightInput, nearest, intensity);
    outputTexture.write(half4(half3(straightOutput * alpha), half(alpha)), grid);
}
