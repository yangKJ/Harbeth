//
//  C7UnsharpMask.metal
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7UnsharpMask(texture2d<float, access::write> outputTexture [[texture(0)]],
                          texture2d<float, access::read> inputTexture [[texture(1)]],
                          constant float *radiusPointer [[buffer(0)]],
                          constant float *intensityPointer [[buffer(1)]],
                          constant float *thresholdPointer [[buffer(2)]],
                          uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    if (!isfinite(*radiusPointer) || !isfinite(*intensityPointer) || !isfinite(*thresholdPointer) || *radiusPointer <= 0.0f || *intensityPointer <= 0.0f) {
        outputTexture.write(inputTexture.read(grid), grid);
        return;
    }
    const int radius = max(int(round(*radiusPointer)), 1);
    const float intensity = max(*intensityPointer, 0.0f);
    const float threshold = clamp(*thresholdPointer, 0.0f, 1.0f);

    const int width = int(inputTexture.get_width());
    const int height = int(inputTexture.get_height());
    const float sigma = max(float(radius) * 0.5f, 0.75f);
    float4 blurred = float4(0.0f);
    float weightSum = 0.0f;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            const int sampleX = clamp(int(grid.x) + x, 0, width - 1);
            const int sampleY = clamp(int(grid.y) + y, 0, height - 1);
            const float distance2 = float(x * x + y * y);
            const float weight = exp(-distance2 / (2.0f * sigma * sigma));
            blurred += float4(inputTexture.read(uint2(sampleX, sampleY))) * weight;
            weightSum += weight;
        }
    }

    const float4 center = inputTexture.read(grid);
    if (weightSum > 0.0f) {
        blurred /= weightSum;
    }

    const float3 detail = center.rgb - blurred.rgb;
    const float luminanceDelta = max(max(fabs(detail.r), fabs(detail.g)), fabs(detail.b));
    const float mask = luminanceDelta > threshold ? 1.0f : 0.0f;
    const float3 sharpened = clamp(center.rgb + detail * intensity * mask, float3(0), float3(1));

    outputTexture.write(float4(sharpened, center.a), grid);
}
