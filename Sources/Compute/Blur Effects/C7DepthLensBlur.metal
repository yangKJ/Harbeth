//
//  C7DepthLensBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/8/17.
//

#include <metal_stdlib>
using namespace metal;

static int2 c7DepthLensBlurClamp(int2 point, uint width, uint height) {
    return clamp(point, int2(0), int2(max(int(width) - 1, 0), max(int(height) - 1, 0)));
}

static float c7DepthLensBlurDepth(texture2d<float, access::read> texture, float2 canvasUV) {
    const float2 size = float2(texture.get_width(), texture.get_height());
    const float2 point = clamp(canvasUV, float2(0.0), float2(1.0)) * size - 0.5;
    const int2 base = int2(floor(point));
    const float2 fraction = clamp(point - float2(base), float2(0.0), float2(1.0));
    const int2 p00 = c7DepthLensBlurClamp(base, texture.get_width(), texture.get_height());
    const int2 p10 = c7DepthLensBlurClamp(base + int2(1, 0), texture.get_width(), texture.get_height());
    const int2 p01 = c7DepthLensBlurClamp(base + int2(0, 1), texture.get_width(), texture.get_height());
    const int2 p11 = c7DepthLensBlurClamp(base + int2(1, 1), texture.get_width(), texture.get_height());
    const float4 samples = float4(texture.read(uint2(p00)).r, texture.read(uint2(p10)).r,
                                  texture.read(uint2(p01)).r, texture.read(uint2(p11)).r);
    const float4 weights = float4((1.0 - fraction.x) * (1.0 - fraction.y),
                                  fraction.x * (1.0 - fraction.y),
                                  (1.0 - fraction.x) * fraction.y,
                                  fraction.x * fraction.y);
    const bool4 valid = isfinite(samples);
    const float4 weighted = select(float4(0.0), weights, valid);
    const float weight = dot(weighted, float4(1.0));
    return weight > 0.0 ? dot(select(float4(0.0), samples, valid), weighted) / weight : NAN;
}

kernel void C7DepthLensBlur(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<float, access::read> depthTexture [[texture(2)]],
    constant float *parameters [[buffer(0)]],
    constant float *mappingContext [[buffer(30)]],
    uint2 grid [[thread_position_in_grid]]
) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }

    const float2 inputOrigin = float2(mappingContext[0], mappingContext[1]);
    const float2 outputOrigin = float2(mappingContext[4], mappingContext[5]);
    const float2 logicalSize = max(float2(mappingContext[6], mappingContext[7]), float2(1.0));
    const float2 globalPixel = outputOrigin + float2(grid);
    const int2 inputPixel = c7DepthLensBlurClamp(
        int2(round(globalPixel - inputOrigin)), inputTexture.get_width(), inputTexture.get_height()
    );
    const half4 original = inputTexture.read(uint2(inputPixel));
    const float intensity = clamp(parameters[2], 0.0, 1.0);
    const float radius = max(parameters[5], 0.0);
    if (intensity <= 0.0 || radius <= 0.0) {
        outputTexture.write(original, grid);
        return;
    }

    const float2 uv = clamp((globalPixel + 0.5) / logicalSize, float2(0.0), float2(1.0));
    const float focusDepth = c7DepthLensBlurDepth(depthTexture, float2(parameters[0], parameters[1]));
    const float currentDepth = c7DepthLensBlurDepth(depthTexture, uv);
    if (!isfinite(focusDepth) || !isfinite(currentDepth)) {
        outputTexture.write(original, grid);
        return;
    }
    const float coc = smoothstep(
        max(parameters[3], 0.005),
        max(parameters[3] + parameters[4], 0.01),
        abs(currentDepth - focusDepth)
    ) * intensity;
    if (coc <= 0.0001) {
        outputTexture.write(original, grid);
        return;
    }

    const float sampleRadius = radius * coc;
    const float2 offsets[13] = {
        float2(0.0), float2(1.0, 0.0), float2(-1.0, 0.0), float2(0.5, 0.866),
        float2(-0.5, 0.866), float2(0.5, -0.866), float2(-0.5, -0.866),
        float2(2.0, 0.0), float2(-2.0, 0.0), float2(1.0, 1.732),
        float2(-1.0, 1.732), float2(1.0, -1.732), float2(-1.0, -1.732)
    };
    half3 sum = half3(0.0);
    float weightSum = 0.0;
    for (uint index = 0; index < 13; index++) {
        const float weight = index == 0 ? 0.24 : (index < 7 ? 0.10 : 0.026);
        // Round relative offsets symmetrically so mirrored sampling does not favor either side.
        const int2 sampleOffset = int2(round(offsets[index] * sampleRadius));
        const int2 point = c7DepthLensBlurClamp(
            inputPixel + sampleOffset,
            inputTexture.get_width(), inputTexture.get_height()
        );
        sum += inputTexture.read(uint2(point)).rgb * half(weight);
        weightSum += weight;
    }
    const half3 blurred = sum / half(max(weightSum, 0.0001));
    outputTexture.write(half4(mix(original.rgb, blurred, half(coc)), original.a), grid);
}
