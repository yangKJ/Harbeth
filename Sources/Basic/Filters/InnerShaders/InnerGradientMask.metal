#include <metal_stdlib>
using namespace metal;

kernel void InnerGradientMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *kindPointer [[buffer(0)]],
                              constant float *value1Pointer [[buffer(1)]],
                              constant float *value2Pointer [[buffer(2)]],
                              constant float *value3Pointer [[buffer(3)]],
                              constant float *value4Pointer [[buffer(4)]],
                              constant float *value5Pointer [[buffer(5)]],
                              constant float *value6Pointer [[buffer(6)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 uv = (float2(grid) + 0.5f) / size;
    const float kind = *kindPointer;

    float coverage = 0.0f;
    if (kind < 0.5f) {
        const float2 startPoint = float2(*value1Pointer, *value2Pointer);
        const float2 endPoint = float2(*value3Pointer, *value4Pointer);
        const float2 delta = endPoint - startPoint;
        const float denominator = max(dot(delta, delta), 0.000001f);
        coverage = clamp(dot(uv - startPoint, delta) / denominator, 0.0f, 1.0f);
    } else {
        const float2 center = float2(*value1Pointer, *value2Pointer);
        const float startRadius = max(*value5Pointer, 0.0f);
        const float endRadius = max(*value6Pointer, startRadius + 0.000001f);
        const float distanceToCenter = distance(uv, center);
        coverage = 1.0f - smoothstep(startRadius, endRadius, distanceToCenter);
    }

    outputTexture.write(half4(half3(coverage), 1.0h), grid);
}
