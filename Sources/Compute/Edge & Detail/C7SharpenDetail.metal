//
//  C7SharpenDetail.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

static inline float4 spatialSample(texture2d<float, access::sample> input, uint2 p, int2 offset, float spacing) {
    if (spacing == 1.0f) {
        return input.read(uint2(clamp(int2(p) + offset, int2(0), int2(input.get_width() - 1, input.get_height() - 1))));
    }
    constexpr sampler linearClamp(coord::pixel, address::clamp_to_edge, filter::linear);
    return input.sample(linearClamp, float2(p) + 0.5f + float2(offset) * spacing);
}

kernel void C7SharpenDetail(texture2d<float, access::write> outputTexture [[texture(0)]],
                            texture2d<float, access::sample> inputTexture [[texture(1)]],
                            constant float *sharpen [[buffer(0)]],
                            constant float *clarity [[buffer(1)]],
                            constant float *detail [[buffer(2)]],
                            constant float *sampleSpacing [[buffer(3)]],
                            uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }
    const float4 inColor = inputTexture.read(grid);
    
    const float sharpenAmount = float(*sharpen);
    const float clarityAmount = float(*clarity);
    const float detailAmount = float(*detail);
    
    if (!isfinite(*sharpen) || !isfinite(*clarity) || !isfinite(*detail) || !isfinite(*sampleSpacing) ||
        (sharpenAmount <= 0 && clarityAmount <= 0 && detailAmount <= 0)) {
        outputTexture.write(inColor, grid);
        return;
    }
    float3 color = inColor.rgb;
    
    if (sharpenAmount > 0.0f) {
        const float3x3 sharpenKernel = float3x3(-1.0, -1.0, -1.0,
                                                -1.0, 9.0, -1.0,
                                                -1.0, -1.0, -1.0);
        float3 sharpenedColor = float3(0.0f, 0.0f, 0.0f);
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float3 sample = spatialSample(inputTexture, grid, int2(x, y), *sampleSpacing).rgb;
                sharpenedColor += sample * float(sharpenKernel[x + 1][y + 1]);
            }
        }
        color = mix(color, sharpenedColor, sharpenAmount);
    }

    if (clarityAmount > 0.0f) {
        float3 localMean = float3(0.0f);
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                localMean += float3(spatialSample(inputTexture, grid, int2(x, y), *sampleSpacing).rgb);
            }
        }
        localMean /= 9.0f;
        const float3 luminanceWeighting = float3(0.2125f, 0.7154f, 0.0721f);
        const float luminance = dot(color, luminanceWeighting);
        const float midtoneDistance = abs(luminance - 0.5f) * 2.0f;
        const float midtoneMask = 1.0f - smoothstep(0.35f, 0.9f, midtoneDistance);
        color += (color - localMean) * clarityAmount * midtoneMask * 0.75f;
    }

    if (detailAmount > 0.0f) {
        const float3x3 detailKernel = float3x3(0.0, -0.25, 0.0,
                                               -0.25, 2.0, -0.25,
                                               0.0, -0.25, 0.0);
        float3 detailedColor = float3(0.0f, 0.0f, 0.0f);
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float3 sample = spatialSample(inputTexture, grid, int2(x, y), *sampleSpacing).rgb;
                detailedColor += sample * float(detailKernel[x + 1][y + 1]);
            }
        }
        color = mix(color, detailedColor, detailAmount * 0.5f);
    }
    const float4 outColor = float4(color, inColor.a);
    
    outputTexture.write(outColor, grid);
}
