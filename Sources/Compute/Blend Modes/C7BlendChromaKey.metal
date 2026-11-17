// 由 Condy 维护。公开类型是单输入抠色，原白色默认key与控制槽位保持。
#include <metal_stdlib>
using namespace metal;
kernel void C7BlendChromaKey(
    texture2d<float, access::write> output [[texture(0)]], texture2d<float, access::read> input [[texture(1)]],
    constant float2 &keying [[buffer(0)]], constant float3 &key [[buffer(1)]],
    constant float &intensity [[buffer(2)]], constant float &halfOutput [[buffer(3)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= output.get_width() || grid.y >= output.get_height()) return;
    const float4 source = input.read(grid);
    if (!isfinite(intensity) || intensity <= 0.0f) { output.write(halfOutput > 0.5f ? float4(half4(source)) : source, grid); return; }
    if (source.a <= 0.0f) { output.write(float4(0), grid); return; }
    const float3 color = source.rgb / source.a;
    const float y = dot(color, float3(0.2989f, 0.5866f, 0.1145f));
    const float keyY = dot(key, float3(0.2989f, 0.5866f, 0.1145f));
    const float distance = length(float2(0.7132f * (color.r - y), 0.5647f * (color.b - y))
                               - float2(0.7132f * (key.r - keyY), 0.5647f * (key.b - keyY)));
    const float keep = keying.y <= 0.0f ? (distance > keying.x ? 1.0f : 0.0f) : smoothstep(keying.x, keying.x + keying.y, distance);
    const float4 result = source * (1.0f - intensity * (1.0f - keep));
    output.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
