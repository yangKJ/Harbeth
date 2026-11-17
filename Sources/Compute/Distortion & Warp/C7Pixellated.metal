// 由 Condy 维护。输出全局网格对齐后映射回输入 ROI。
#include <metal_stdlib>
using namespace metal;
kernel void C7Pixellated(texture2d<float, access::write> outputTexture [[texture(0)]],
                         texture2d<float, access::read> inputTexture [[texture(1)]],
                         constant float &pixelScale [[buffer(0)]],
                         constant float &halfOutput [[buffer(1)]],
                         constant float4 *context [[buffer(30)]],
                         uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float2 logical = max(context[1].zw,float2(1.0f));
    const float2 uv = (float2(grid)+context[1].xy)/logical;
    float2 sample = uv;
    if (isfinite(pixelScale) && pixelScale > 0.0f) sample = uv-fmod(uv,float2(pixelScale))+pixelScale*0.5f;
    const bool directPixel = (!isfinite(pixelScale) || pixelScale <= 0.0f) && all(context[0].zw == logical);
    const float2 local = directPixel ? float2(grid) + context[1].xy - context[0].xy
                                    : clamp(sample, 0.0f, 1.0f) * context[0].zw - context[0].xy;
    const int2 point = clamp(int2(local),int2(0),int2(inputTexture.get_width()-1,inputTexture.get_height()-1));
    const float4 value = inputTexture.read(uint2(point));
    outputTexture.write(halfOutput > 0.5f ? float4(half4(value)) : value,grid);
}
