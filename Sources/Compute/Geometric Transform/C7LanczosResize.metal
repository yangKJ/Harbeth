//
//  C7LanczosResize.metal
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

constant float kLanczosSupport = 3.0f;

float lanczosWeight(float x) {
    x = fabs(x);
    if (x < 1e-5f) {
        return 1.0f;
    }
    if (x >= kLanczosSupport) {
        return 0.0f;
    }
    const float pix = M_PI_F * x;
    const float pixOverSupport = pix / kLanczosSupport;
    return (sin(pix) / pix) * (sin(pixOverSupport) / pixOverSupport);
}

kernel void C7LanczosResize(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const uint outWidth = outputTexture.get_width();
    const uint outHeight = outputTexture.get_height();
    if (grid.x >= outWidth || grid.y >= outHeight) {
        return;
    }

    const float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 outputSize = float2(outWidth, outHeight);
    const float2 scale = inputSize / outputSize;
    const float2 source = (float2(grid) + 0.5f) * scale - 0.5f;
    const int2 base = int2(floor(source));

    float4 color = float4(0.0f);
    float weightSum = 0.0f;

    for (int y = -2; y <= 3; y++) {
        for (int x = -2; x <= 3; x++) {
            const int2 sample = base + int2(x, y);
            const int sampleX = clamp(sample.x, 0, int(inputTexture.get_width()) - 1);
            const int sampleY = clamp(sample.y, 0, int(inputTexture.get_height()) - 1);
            const float2 sampleCenter = float2(sampleX, sampleY);
            const float wx = lanczosWeight(source.x - sampleCenter.x);
            const float wy = lanczosWeight(source.y - sampleCenter.y);
            const float weight = wx * wy;
            if (weight == 0.0f) {
                continue;
            }
            color += float4(inputTexture.read(uint2(sampleX, sampleY))) * weight;
            weightSum += weight;
        }
    }

    if (weightSum > 0.0f) {
        color /= weightSum;
    } else {
        color = float4(inputTexture.read(uint2(clamp(int(source.x), 0, int(inputTexture.get_width()) - 1),
                                               clamp(int(source.y), 0, int(inputTexture.get_height()) - 1))));
    }

    outputTexture.write(half4(clamp(color, 0.0f, 1.0f)), grid);
}
