// 由 Condy 维护。增强加深方程保持，前景覆盖调制颜色且不改变背景Alpha。
#include <metal_stdlib>
using namespace metal;
kernel void C7ColorBurnEnhancedBlend(
    texture2d<float, access::write> output [[texture(0)]], texture2d<float, access::read> input [[texture(1)]],
    texture2d<float, access::sample> foreground [[texture(2)]], constant float &intensity [[buffer(0)]],
    constant float &strength [[buffer(1)]], constant float &halfOutput [[buffer(2)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (!isfinite(intensity) || intensity <= 0.0f) { output.write(halfOutput > 0.5f ? float4(half4(source)) : source, grid); return; }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    const float4 layer = foreground.sample(sampling, (float2(grid) + 0.5f) / float2(output.get_width(), output.get_height()));
    if (layer.a <= 0.0f) { output.write(halfOutput > 0.5f ? float4(half4(source)) : source, grid); return; }
    const float3 base = source.rgb / source.a, blend = layer.rgb / layer.a;
    const float3 mapped = 1.0f - min(1.0f, (1.0f - base) / max(blend * strength, float3(float(half(0.0001f)))));
    const float amount = intensity * clamp(layer.a, 0.0f, 1.0f);
    const float3 mixed = amount >= 1.0f ? mapped : base * (1.0f - amount) + mapped * amount;
    const float4 result = float4(mixed * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
