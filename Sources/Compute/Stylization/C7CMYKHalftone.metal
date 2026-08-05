//
//  C7CMYKHalftone.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

static float2 cmykRotate(float2 point, float angle) {
    const float sine = sin(angle);
    const float cosine = cos(angle);
    return float2(cosine * point.x - sine * point.y, sine * point.x + cosine * point.y);
}

static float4 cmykAtPixel(texture2d<half, access::read> inputTexture,
                          float2 globalPixel,
                          float4 inputRegion) {
    const float2 localPixel = globalPixel - inputRegion.xy;
    const int2 maximum = int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1);
    const int2 coordinate = clamp(int2(round(localPixel)), int2(0), maximum);
    const half4 sample = inputTexture.read(uint2(coordinate));
    const float alpha = float(sample.a);
    if (alpha <= 0.0f) { return float4(0.0f); }
    const float3 rgb = alpha > 0.0f ? clamp(float3(sample.rgb) / alpha, 0.0f, 1.0f) : float3(0.0f);
    const float black = 1.0f - max(rgb.r, max(rgb.g, rgb.b));
    const float denominator = max(1.0f - black, 0.0001f);
    return float4(
        (1.0f - rgb.r - black) / denominator,
        (1.0f - rgb.g - black) / denominator,
        (1.0f - rgb.b - black) / denominator,
        black
    );
}

static float cmykScreenCoverage(texture2d<half, access::read> inputTexture,
                                float2 globalPixel,
                                float2 canvasSize,
                                float4 inputRegion,
                                float cellSize,
                                float angle,
                                int channel) {
    const float2 centeredPixel = globalPixel - canvasSize * 0.5f;
    const float2 rotatedPixel = cmykRotate(centeredPixel, angle);
    const float2 cellCenter = (floor(rotatedPixel / cellSize) + 0.5f) * cellSize;
    const float2 samplePixel = cmykRotate(cellCenter, -angle) + canvasSize * 0.5f;
    const float ink = clamp(cmykAtPixel(inputTexture, samplePixel, inputRegion)[channel], 0.0f, 1.0f);
    if (ink <= 0.0f) { return 0.0f; }

    const float radius = cellSize * 0.5f * sqrt(ink);
    const float edgeWidth = max(1.0f, cellSize * 0.035f);
    const float pointDistance = length(rotatedPixel - cellCenter);
    return 1.0f - smoothstep(radius - edgeWidth, radius + edgeWidth, pointDistance);
}

kernel void C7CMYKHalftone(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *fractionalWidthPointer [[buffer(0)]],
                           constant float *intensityPointer [[buffer(1)]],
                           constant float4 *regionContext [[buffer(30)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }

    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float2 canvasSize = outputRegion.zw;
    const float2 globalPixel = float2(grid) + outputRegion.xy + 0.5f;
    const float cellSize = max(
        2.0f,
        clamp(*fractionalWidthPointer, 0.002f, 0.2f) * min(canvasSize.x, canvasSize.y)
    );

    constexpr float degreesToRadians = M_PI_F / 180.0f;
    const float cyan = cmykScreenCoverage(inputTexture, globalPixel, canvasSize, inputRegion, cellSize, 15.0f * degreesToRadians, 0);
    const float magenta = cmykScreenCoverage(inputTexture, globalPixel, canvasSize, inputRegion, cellSize, 75.0f * degreesToRadians, 1);
    const float yellow = cmykScreenCoverage(inputTexture, globalPixel, canvasSize, inputRegion, cellSize, 0.0f, 2);
    const float black = cmykScreenCoverage(inputTexture, globalPixel, canvasSize, inputRegion, cellSize, 45.0f * degreesToRadians, 3);

    const half4 input = inputTexture.read(grid);
    const float alpha = float(input.a);
    const float3 straightInput = alpha > 0.0f ? clamp(float3(input.rgb) / alpha, 0.0f, 1.0f) : float3(0.0f);
    const float3 printColor = float3(
        (1.0f - cyan) * (1.0f - black),
        (1.0f - magenta) * (1.0f - black),
        (1.0f - yellow) * (1.0f - black)
    );
    const float intensity = clamp(*intensityPointer, 0.0f, 1.0f);
    const float3 straightOutput = mix(straightInput, printColor, intensity);
    outputTexture.write(half4(half3(straightOutput * alpha), half(alpha)), grid);
}
