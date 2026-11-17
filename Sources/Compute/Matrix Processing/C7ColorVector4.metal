// 由 Condy 维护。偏移使用单精度工作值，零强度在加法前旁路。
#include <metal_stdlib>
using namespace metal;
kernel void C7ColorVector4(
    texture2d<float, access::write> output [[texture(0)]],
    texture2d<float, access::read> input [[texture(1)]],
    constant float &intensity [[buffer(0)]], constant float4 &offset [[buffer(1)]],
    constant float &halfOutput [[buffer(2)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (!isfinite(intensity) || intensity <= 0.0f) { output.write(source, grid); return; }
    const float4 result = source + offset * intensity;
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
