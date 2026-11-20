// 由 Condy 维护。两色仍按原亮度权重映射，输出恢复源覆盖。
#include <metal_stdlib>
using namespace metal;

kernel void C7FalseColor(texture2d<float, access::write> output [[texture(0)]],
                         texture2d<float, access::read> input [[texture(1)]],
                         constant float3 &first [[buffer(0)]],
                         constant float3 &second [[buffer(1)]],
                         constant float &halfOutput [[buffer(2)]],
                         uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    const float luminance = dot(source.rgb / source.a, float3(0.2125f, 0.7154f, 0.0721f));
    const float4 result = float4(mix(first, second, luminance) * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
