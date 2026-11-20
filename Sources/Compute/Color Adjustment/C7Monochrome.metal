// 由 Condy 维护。保留原单色叠色方程，直色求值后恢复覆盖。
#include <metal_stdlib>
using namespace metal;

kernel void C7Monochrome(texture2d<float, access::write> output [[texture(0)]],
                         texture2d<float, access::read> input [[texture(1)]],
                         constant float &intensity [[buffer(0)]],
                         constant float &red [[buffer(1)]],
                         constant float &green [[buffer(2)]],
                         constant float &blue [[buffer(3)]],
                         constant float &halfOutput [[buffer(4)]],
                         uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (!isfinite(intensity) || intensity <= 0.0f) {
        output.write(halfOutput > 0.5f ? float4(half4(source)) : source, grid);
        return;
    }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    const float3 color = source.rgb / source.a;
    const float luminance = dot(color, float3(0.2125f, 0.7154f, 0.0721f));
    const float3 tint = float3(red, green, blue);
    const float3 mapped = luminance < 0.5f ? 2.0f * luminance * tint : 1.0f - 2.0f * (1.0f - luminance) * (1.0f - tint);
    const float3 mixed = intensity >= 1.0f ? mapped : color * (1.0f - intensity) + mapped * intensity;
    const float4 result = float4(mixed * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
