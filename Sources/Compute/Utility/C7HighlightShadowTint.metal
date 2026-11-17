// 由 Condy 维护。保留目录染色组合顺序，零调整在危险插值前旁路。
#include <metal_stdlib>
using namespace metal;
kernel void C7HighlightShadowTint(
    texture2d<float, access::write> output [[texture(0)]], texture2d<float, access::read> input [[texture(1)]],
    constant float &shadowAmount [[buffer(0)]], constant float &highlightAmount [[buffer(1)]],
    constant float3 &shadowColor [[buffer(2)]], constant float3 &highlightColor [[buffer(3)]],
    constant float &halfOutput [[buffer(4)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (shadowAmount == 0.0f && highlightAmount == 0.0f) { output.write(halfOutput > 0.5f ? float4(half4(source)) : source, grid); return; }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    const float3 color = source.rgb / source.a;
    const float luminance = dot(color, float3(0.2125f, 0.7154f, 0.0721f));
    const float3 shadow = shadowAmount == 0.0f ? color : mix(color, max(color, mix(shadowColor, color, luminance)), shadowAmount);
    const float3 highlight = highlightAmount == 0.0f ? color : mix(color, min(shadow, mix(shadow, highlightColor, luminance)), highlightAmount);
    const float4 result = float4(mix(shadow, highlight, luminance) * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
