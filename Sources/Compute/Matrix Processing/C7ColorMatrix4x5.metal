// 由 Condy 维护。原始RGBA行点积保持，运算前旁路零强度，最终按目标格式舍入。
#include <metal_stdlib>
using namespace metal;
kernel void C7ColorMatrix4x5(
    texture2d<float, access::write> output [[texture(0)]],
    texture2d<float, access::read> input [[texture(1)]],
    constant float &intensity [[buffer(0)]],
    constant float4x4 &matrix [[buffer(1)]],
    constant float4 &offset [[buffer(2)]],
    constant float &halfOutput [[buffer(3)]],
    uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (!isfinite(intensity) || intensity <= 0.0f) { output.write(source, grid); return; }
    const float4 mapped = float4(dot(source, matrix[0]), dot(source, matrix[1]),
                                 dot(source, matrix[2]), dot(source, matrix[3])) + offset;
    const float4 result = intensity >= 1.0f ? mapped : source * (1.0f - intensity) + mapped * intensity;
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
