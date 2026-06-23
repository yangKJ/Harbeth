#include <metal_stdlib>
using namespace metal;

kernel void InnerShapeMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *kindPointer [[buffer(0)]],
                           constant float *xPointer [[buffer(1)]],
                           constant float *yPointer [[buffer(2)]],
                           constant float *widthPointer [[buffer(3)]],
                           constant float *heightPointer [[buffer(4)]],
                           constant float *featherPointer [[buffer(5)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const float2 uv = (float2(grid) + 0.5f) / float2(outputTexture.get_width(), outputTexture.get_height());
    const float kind = *kindPointer;
    const float2 origin = float2(*xPointer, *yPointer);
    const float2 size = max(float2(*widthPointer, *heightPointer), float2(0.000001f));
    const float feather = clamp(*featherPointer, 0.0f, 1.0f);

    float coverage = 0.0f;
    if (kind < 0.5f) {
        const float2 local = (uv - origin) / size;
        const float2 edgeDistance = min(local, 1.0f - local);
        const float minEdge = min(edgeDistance.x, edgeDistance.y);
        const float featherWidth = max(feather * 0.5f, 0.000001f);
        coverage = smoothstep(0.0f, featherWidth, minEdge);
        coverage *= step(0.0f, local.x) * step(0.0f, local.y) * step(local.x, 1.0f) * step(local.y, 1.0f);
    } else {
        const float2 center = origin + size * 0.5f;
        const float2 radius = size * 0.5f;
        const float2 normalized = (uv - center) / max(radius, float2(0.000001f));
        const float distanceValue = length(normalized);
        const float featherWidth = max(feather, 0.000001f);
        coverage = 1.0f - smoothstep(1.0f - featherWidth, 1.0f, distanceValue);
    }

    outputTexture.write(half4(half3(clamp(coverage, 0.0f, 1.0f)), 1.0h), grid);
}
