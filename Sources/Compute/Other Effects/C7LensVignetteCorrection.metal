//
//  C7LensVignetteCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LensVignetteCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                     constant float *centerX [[buffer(0)]],
                                     constant float *centerY [[buffer(1)]],
                                     constant float *amount [[buffer(2)]],
                                     constant float *start [[buffer(3)]],
                                     constant float *end [[buffer(4)]],
                                     uint2 grid [[thread_position_in_grid]]) {

    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 inputColor = inputTexture.read(grid);
    const float2 uv = float2(
        (float(grid.x) + 0.5f) / float(outputTexture.get_width()),
        (float(grid.y) + 0.5f) / float(outputTexture.get_height())
    );
    const float2 center = float2(*centerX, *centerY);

    const float2 aspect = float2(
        float(outputTexture.get_width()) / max(float(outputTexture.get_height()), 1.0f),
        1.0f
    );
    const float radius = length((uv - center) * aspect);
    const float feather = smoothstep(*start, *end, radius);
    const float gain = pow(2.0f, feather * (*amount));

    const half3 rgb = min(inputColor.rgb * half(gain), half3(1.0h));
    outputTexture.write(half4(rgb, inputColor.a), grid);
}
