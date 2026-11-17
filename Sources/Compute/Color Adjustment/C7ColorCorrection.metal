// 由 Condy 维护。保留目录色阶/曲线/平衡顺序，在直色域计算后关联。
#include <metal_stdlib>
using namespace metal;
kernel void C7ColorCorrection(
    texture2d<float, access::write> output [[texture(0)]], texture2d<float, access::read> input [[texture(1)]],
    constant float &levels [[buffer(0)]], constant float &curves [[buffer(1)]],
    constant float &balance [[buffer(2)]], constant float &halfOutput [[buffer(3)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (levels == 0.0f && curves == 0.0f && balance == 0.0f) { output.write(source, grid); return; }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    float3 color = source.rgb / source.a;
    if (levels != 0.0f) {
        const float low = abs(levels) * 0.1f, high = 1.0f - low;
        color = pow(max((color - low) / (high - low), 0.0f), float3(1.0f - levels * 0.3f));
    }
    if (curves != 0.0f) {
        const float exponent = 1.0f + abs(curves) * 0.5f;
        for (uint c = 0; c < 3; c++) {
            if (color[c] >= 0.0f && color[c] < 0.5f) color[c] = pow(color[c] / 0.5f, exponent) * 0.5f;
            else if (color[c] >= 0.5f && color[c] <= 1.0f) color[c] = 1.0f - pow((1.0f - color[c]) / 0.5f, exponent) * 0.5f;
        }
    }
    color += balance * 0.2f * float3(0.5f, 0.2f, -0.3f);
    const float4 result = float4(color * source.a, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
