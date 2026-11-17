// 由 Condy 维护。亮度与对比度在直色域计算，原覆盖率不变。
#include <metal_stdlib>
using namespace metal;
kernel void C7LuminanceAdaptiveContrast(
    texture2d<float, access::write> output [[texture(0)]], texture2d<float, access::read> input [[texture(1)]],
    constant float &amount [[buffer(0)]], constant float &adaptivity [[buffer(1)]],
    constant float &halfOutput [[buffer(2)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (amount == 0.0f || adaptivity == 0.0f) { output.write(source, grid); return; }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    const float3 color = source.rgb / source.a;
    const float luminance = dot(color, float3(0.299f, 0.587f, 0.114f));
    const float contrast = 1.0f + amount * (0.5f - luminance) * 4.0f * adaptivity;
    const float4 result = float4(((color - 0.5f) * contrast + 0.5f) * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
