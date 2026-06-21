//
//  C7NoiseReduction.metal
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

float luminance(float3 color) {
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

kernel void C7NoiseReduction(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *factors [[buffer(0)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const uint width = outputTexture.get_width();
    const uint height = outputTexture.get_height();
    if (grid.x >= width || grid.y >= height) {
        return;
    }

    const int radius = max(int(round(factors[0])), 1);
    const float amount = clamp(factors[1], 0.0f, 1.0f);
    const float edgePreservation = clamp(factors[2], 0.0f, 1.0f);
    const float colorSigma = mix(0.25f, 0.03f, edgePreservation);

    const float4 center = float4(inputTexture.read(grid));
    const float centerLuma = luminance(center.rgb);
    float4 accumulated = float4(0.0f);
    float weightSum = 0.0f;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            const int sampleX = clamp(int(grid.x) + x, 0, int(width) - 1);
            const int sampleY = clamp(int(grid.y) + y, 0, int(height) - 1);
            const float4 sample = float4(inputTexture.read(uint2(sampleX, sampleY)));
            const float spatialDistance = float(x * x + y * y);
            const float spatialWeight = exp(-spatialDistance / max(float(radius * radius), 1.0f));
            const float colorDistance = fabs(luminance(sample.rgb) - centerLuma);
            const float colorWeight = exp(-(colorDistance * colorDistance) / max(colorSigma * colorSigma, 1e-5f));
            const float weight = spatialWeight * colorWeight;
            accumulated += sample * weight;
            weightSum += weight;
        }
    }

    float4 denoised = center;
    if (weightSum > 0.0f) {
        denoised = accumulated / weightSum;
    }
    denoised.a = center.a;

    outputTexture.write(half4(mix(center, denoised, amount)), grid);
}
