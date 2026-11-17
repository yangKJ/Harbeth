//
//  C7LensVignetteCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LensVignetteCorrection(texture2d<float, access::write> outputTexture [[texture(0)]],
                                     texture2d<float, access::read> inputTexture [[texture(1)]],
                                     constant float *centerX [[buffer(0)]],
                                     constant float *centerY [[buffer(1)]],
                                     constant float *amount [[buffer(2)]],
                                     constant float *start [[buffer(3)]],
                                     constant float *end [[buffer(4)]],
                                     constant float &halfOutput [[buffer(5)]],
                                     uint2 grid [[thread_position_in_grid]]) {

    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float4 inputColor = inputTexture.read(grid);
    if (*amount == 0.0f) { outputTexture.write(inputColor, grid); return; }
    if (inputColor.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
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
    const float feather = *start == *end ? step(*start, radius) : smoothstep(min(*start, *end), max(*start, *end), radius);
    const float gain = pow(2.0f, feather * (*amount));

    // 保留原 SDR 上限，在直色域裁剪后恢复预乘关联。
    const float3 rgb = min(inputColor.rgb / inputColor.a * gain, float3(1.0f)) * inputColor.a;
    const float4 result = isfinite(gain) ? float4(rgb, inputColor.a) : inputColor;
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
