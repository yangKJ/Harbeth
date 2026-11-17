//
//  C7NoiseReduction.metal
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

float luminance(float3 color) {
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

static inline float4 spatialSample(texture2d<float, access::sample> input, uint2 p, int2 offset, float spacing) {
    if (spacing == 1.0f) {
        return input.read(uint2(clamp(int2(p) + offset, int2(0), int2(input.get_width() - 1, input.get_height() - 1))));
    }
    constexpr sampler linearClamp(coord::pixel, address::clamp_to_edge, filter::linear);
    return input.sample(linearClamp, float2(p) + 0.5f + float2(offset) * spacing);
}

kernel void C7NoiseReduction(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::sample> inputTexture [[texture(1)]],
                             constant float *radiusPointer [[buffer(0)]],
                             constant float *amountPointer [[buffer(1)]],
                             constant float *edgePreservationPointer [[buffer(2)]],
                             constant float *sampleSpacing [[buffer(3)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const uint width = outputTexture.get_width();
    const uint height = outputTexture.get_height();
    if (grid.x >= width || grid.y >= height) {
        return;
    }

    const float amount = clamp(*amountPointer, 0.0f, 1.0f);
    const float edgePreservation = clamp(*edgePreservationPointer, 0.0f, 1.0f);
    const float colorSigma = mix(0.35f, 0.08f, edgePreservation);

    const float4 center = float4(inputTexture.read(grid));
    if (!isfinite(*amountPointer) || !isfinite(*radiusPointer) || !isfinite(*edgePreservationPointer) || !isfinite(*sampleSpacing) || amount <= 0.0f) { outputTexture.write(center, grid); return; }
    const int radius = max(int(round(*radiusPointer)), 1);
    if (center.a <= 0.0f) { outputTexture.write(float4(0.0f), grid); return; }
    const float centerLuma = luminance(center.rgb) / center.a;
    float4 accumulated = float4(0.0f);
    float4 spatialAccumulated = float4(0.0f);

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            const float4 sample = float4(spatialSample(inputTexture, grid, int2(x, y), *sampleSpacing));
            if (sample.a <= 0.0f) continue;
            const float spatialDistance = float(x * x + y * y);
            const float spatialWeight = exp(-spatialDistance / max(float(radius * radius), 1.0f));
            const float colorDistance = fabs(luminance(sample.rgb) / sample.a - centerLuma);
            const float colorWeight = exp(-(colorDistance * colorDistance) / max(colorSigma * colorSigma, 1e-5f));
            const float weight = spatialWeight * colorWeight;
            accumulated += sample * weight;
            spatialAccumulated += sample * spatialWeight;
        }
    }

    // 分母使用同一窗口的有效覆盖，空间均值与脉冲回退都在 straight 域计算。
    const float3 centerColor = center.rgb / center.a;
    const float3 denoised = accumulated.a > 0.0f ? accumulated.rgb / accumulated.a : centerColor;
    const float3 spatialMean = spatialAccumulated.a > 0.0f ? spatialAccumulated.rgb / spatialAccumulated.a : centerColor;
    const float impulseDelta = fabs(centerLuma - luminance(spatialMean));
    const float impulseBlend = clamp((impulseDelta - colorSigma * 0.5f) / max(1.0f - colorSigma * 0.5f, 1e-5f), 0.0f, 1.0f);
    const float impulseStrength = amount * impulseBlend * mix(0.45f, 0.8f, 1.0f - edgePreservation);
    const float3 result = mix(centerColor, mix(denoised, spatialMean, impulseStrength), amount) * center.a;
    outputTexture.write(float4(result, center.a), grid);
}
