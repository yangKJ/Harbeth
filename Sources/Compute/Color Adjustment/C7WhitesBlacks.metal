// 由 Condy 维护。直色分区，保留扩展分量和中心覆盖。
#include <metal_stdlib>
using namespace metal;

kernel void C7WhitesBlacks(texture2d<float, access::write> output [[texture(0)]],
                           texture2d<float, access::read> input [[texture(1)]],
                           constant float &whites [[buffer(0)]],
                           constant float &blacks [[buffer(1)]],
                           constant float &halfOutput [[buffer(2)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (whites == 0.0f && blacks == 0.0f) { output.write(source, grid); return; }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    const float3 straight = source.rgb / source.a;
    const float3 bounded = clamp(straight, 0.0f, 1.0f);
    float3 color = bounded;
    const float luminance = dot(color, float3(0.2126f, 0.7152f, 0.0722f));
    const float whiteAmount = clamp(whites, -1.0f, 1.0f) * smoothstep(0.5f, 1.0f, luminance) * 0.45f;
    color = whiteAmount >= 0.0f ? mix(color, float3(1), whiteAmount) : color * (1.0f + whiteAmount);
    const float blackAmount = clamp(blacks, -1.0f, 1.0f) * (1.0f - smoothstep(0.0f, 0.5f, luminance)) * 0.45f;
    color = blackAmount >= 0.0f ? mix(color, float3(1), blackAmount) : color * (1.0f + blackAmount);
    const float4 result = float4((color + straight - bounded) * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
