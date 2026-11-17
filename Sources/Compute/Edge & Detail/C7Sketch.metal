// 由 Condy 维护。保持步长 2，夹边边界与不透明灰度输出。
#include <metal_stdlib>
using namespace metal;
static float3 C7SketchRead(texture2d<float, access::read> input, int2 p) {
    const int2 size = int2(input.get_width(), input.get_height());
    return input.read(uint2(clamp(p, int2(0), size - 1))).rgb;
}
kernel void C7Sketch(texture2d<float, access::write> outputTexture [[texture(0)]],
                     texture2d<float, access::read> inputTexture [[texture(1)]],
                     constant float &strength [[buffer(0)]],
                     constant float &halfOutput [[buffer(1)]],
                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    float magnitude = 0.0f;
    if (isfinite(strength) && strength != 0.0f) {
        const int2 p = int2(grid);
        const float3 tl = C7SketchRead(inputTexture,p+int2(-2,-2)), t = C7SketchRead(inputTexture,p+int2(0,-2));
        const float3 tr = C7SketchRead(inputTexture,p+int2(2,-2)), l = C7SketchRead(inputTexture,p+int2(-2,0));
        const float3 r = C7SketchRead(inputTexture,p+int2(2,0)), bl = C7SketchRead(inputTexture,p+int2(-2,2));
        const float3 b = C7SketchRead(inputTexture,p+int2(0,2)), br = C7SketchRead(inputTexture,p+int2(2,2));
        const float3 gy = (bl-tl) + 2.0f*(b-t) + (br-tr);
        const float3 gx = (tr-tl) + 2.0f*(r-l) + (br-bl);
        const float3 luma = float3(0.2126f,0.7152f,0.0722f);
        magnitude = length(float2(dot(gx,luma),dot(gy,luma))) * strength;
    }
    const float4 result = float4(float3(1.0f - magnitude),1.0f);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
