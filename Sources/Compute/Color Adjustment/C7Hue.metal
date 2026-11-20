// 由 Condy 维护。保留YIQ系数意图，以线性旋转代替每像素极坐标往返。
#include <metal_stdlib>
using namespace metal;

kernel void C7Hue(texture2d<float, access::write> output [[texture(0)]],
                  texture2d<float, access::read> input [[texture(1)]],
                  constant float &radians [[buffer(0)]],
                  constant float &cosine [[buffer(1)]],
                  constant float &sine [[buffer(2)]],
                  constant float &halfOutput [[buffer(3)]],
                  uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (!isfinite(radians) || radians == 0.0f || radians == 6.283185307179586f) { output.write(source, grid); return; }
    const float y = dot(source.rgb, float3(half3(0.299, 0.587, 0.114)));
    const float i = dot(source.rgb, float3(half3(0.595716, -0.274453, -0.321263)));
    const float q = dot(source.rgb, float3(half3(0.211456, -0.522591, 0.31135)));
    const float3 yiq = float3(y, i * cosine + q * sine, q * cosine - i * sine);
    const float3 color = float3(dot(yiq, float3(half3(1, 0.9563, 0.6210))),
                                dot(yiq, float3(half3(1, -0.2721, -0.6474))),
                                dot(yiq, float3(half3(1, -1.1070, 1.7046))));
    const float4 result = float4(color, source.a);
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
