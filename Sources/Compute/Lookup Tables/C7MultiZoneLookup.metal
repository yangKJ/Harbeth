// 由 Condy 维护。三区权重连续且和为一，参数对应独立 scalar 槽位。
#include <metal_stdlib>
using namespace metal;
static float3 zoneLookup(texture2d<half, access::sample> table, float3 color) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    const float width = float(table.get_width());
    const float3 x = (clamp(color, 0.0f, 1.0f) * (width - 1.0f) + 0.5f) / width;
    return float3(table.sample(s, float2(x.r,0.5f)).r, table.sample(s, float2(x.g,0.5f)).g, table.sample(s, float2(x.b,0.5f)).b);
}
kernel void C7MultiZoneLookup(texture2d<float, access::write> outputTexture [[texture(0)]],
                              texture2d<float, access::read> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> shadowTable [[texture(2)]],
                              texture2d<half, access::sample> midtoneTable [[texture(3)]],
                              texture2d<half, access::sample> highlightTable [[texture(4)]],
                              constant float &shadowThreshold [[buffer(0)]],
                              constant float &highlightThreshold [[buffer(1)]],
                              constant float &transitionWidth [[buffer(2)]],
                              constant float &halfOutput [[buffer(3)]],
                              uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 input = inputTexture.read(grid);
    const float shadow = min(shadowThreshold, highlightThreshold - 0.01f);
    const float highlight = max(highlightThreshold, shadow + 0.01f);
    const float width = clamp(transitionWidth, 0.0f, (highlight - shadow) * 0.5f);
    const float luma = dot(input.rgb, float3(0.299f,0.587f,0.114f));
    float3 weights = float3(0,1,0);
    if (luma <= shadow) weights = float3(1,0,0);
    else if (luma >= highlight) weights = float3(0,0,1);
    else if (width > 0.0f && luma < shadow + width) {
        const float t = clamp((luma - shadow) / width, 0.0f, 1.0f);
        weights = float3(1.0f - t, t, 0);
    } else if (width > 0.0f && luma > highlight - width) {
        const float t = clamp((luma - (highlight - width)) / width, 0.0f, 1.0f);
        weights = float3(0, 1.0f - t, t);
    }
    const float3 s = weights.x > 0.0f ? zoneLookup(shadowTable,input.rgb) : float3(0);
    const float3 m = weights.y > 0.0f ? zoneLookup(midtoneTable,input.rgb) : float3(0);
    const float3 h = weights.z > 0.0f ? zoneLookup(highlightTable,input.rgb) : float3(0);
    const float4 result = float4(s * weights.x + m * weights.y + h * weights.z, input.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
