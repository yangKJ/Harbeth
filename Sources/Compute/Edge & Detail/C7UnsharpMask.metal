//
//  C7UnsharpMask.metal
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7UnsharpMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *factors [[buffer(0)]],
                          uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float radius = max(factors[0], 0.0f) / 100.0f;
    const float intensity = max(factors[1], 0.0f);
    const float threshold = clamp(factors[2], 0.0f, 1.0f);

    const float2 uv = float2(grid) / float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());
    half4 blurred = half4(0.0h);
    const float weights[9] = {
        1.0f, 2.0f, 1.0f,
        2.0f, 4.0f, 2.0f,
        1.0f, 2.0f, 1.0f
    };

    for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
            const float2 offset = float2(x - 1, y - 1) * radius;
            const float2 sampleUV = clamp(uv + offset, 0.0f, 1.0f);
            const uint2 coord = uint2(sampleUV * inputSize);
            blurred += inputTexture.read(coord) * half(weights[y * 3 + x]);
        }
    }

    const half4 center = inputTexture.read(grid);
    blurred /= 16.0h;

    const half3 detail = center.rgb - blurred.rgb;
    const half luminanceDelta = max(max(fabs(detail.r), fabs(detail.g)), fabs(detail.b));
    const half mask = luminanceDelta > half(threshold) ? 1.0h : 0.0h;
    const half3 sharpened = clamp(center.rgb + detail * half(intensity) * mask, half3(0.0h), half3(1.0h));

    outputTexture.write(half4(sharpened, center.a), grid);
}
