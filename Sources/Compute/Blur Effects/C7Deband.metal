//
//  C7Deband.metal
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

#include <metal_stdlib>
using namespace metal;

static inline float c7DebandLuminance(float3 color) {
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

static inline float c7DebandNoise(uint2 grid) {
    const float seed = dot(float2(grid), float2(12.9898f, 78.233f));
    return fract(sin(seed) * 43758.5453f) - 0.5f;
}

kernel void C7Deband(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float *radiusPointer [[buffer(0)]],
                     constant float *thresholdPointer [[buffer(1)]],
                     constant float *amountPointer [[buffer(2)]],
                     constant float *ditherPointer [[buffer(3)]],
                     uint2 grid [[thread_position_in_grid]]) {
    const uint width = outputTexture.get_width();
    const uint height = outputTexture.get_height();
    if (grid.x >= width || grid.y >= height) {
        return;
    }

    const int radius = max(int(round(*radiusPointer)), 1);
    const float threshold = max(*thresholdPointer, 0.0f);
    const float amount = clamp(*amountPointer, 0.0f, 1.0f);
    const float dither = clamp(*ditherPointer, 0.0f, 1.0f);

    const float4 center = float4(inputTexture.read(grid));
    const float centerLuma = c7DebandLuminance(center.rgb);

    float4 accumulated = center;
    float weightSum = 1.0f;
    float localContrast = 0.0f;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            if (x == 0 && y == 0) {
                continue;
            }

            const int sampleX = clamp(int(grid.x) + x, 0, int(width) - 1);
            const int sampleY = clamp(int(grid.y) + y, 0, int(height) - 1);
            const float4 sample = float4(inputTexture.read(uint2(sampleX, sampleY)));
            const float lumaDelta = fabs(c7DebandLuminance(sample.rgb) - centerLuma);
            localContrast = max(localContrast, lumaDelta);

            const float spatialDistance = length(float2(x, y));
            const float spatialWeight = max(0.0f, 1.0f - spatialDistance / float(radius + 1));
            const float similarity = 1.0f - smoothstep(threshold * 0.35f, max(threshold, 1e-5f), lumaDelta);
            const float weight = spatialWeight * similarity;

            accumulated += sample * weight;
            weightSum += weight;
        }
    }

    float4 smoothed = accumulated / max(weightSum, 1e-5f);
    smoothed.a = center.a;

    const float flatRegion = 1.0f - smoothstep(threshold, threshold * 2.5f + 1e-5f, localContrast);
    float4 output = mix(center, smoothed, amount * flatRegion);
    const float noise = c7DebandNoise(grid) * dither * amount * flatRegion / 255.0f;
    output.rgb = clamp(output.rgb + noise, 0.0f, 1.0f);
    output.a = center.a;

    outputTexture.write(half4(output), grid);
}
