// 由 Condy 维护。基础锐化使用单精度差分，保留中心 alpha。
#include <metal_stdlib>
using namespace metal;
kernel void C7Sharpen(texture2d<float, access::write> outputTexture [[texture(0)]],
                      texture2d<float, access::read> inputTexture [[texture(1)]],
                      constant float &sharpness [[buffer(0)]],
                      constant float &halfOutput [[buffer(1)]],
                      uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 center = inputTexture.read(grid);
    float4 result = center;
    if (isfinite(sharpness) && sharpness != 0.0f) {
        const int2 p = int2(grid), maximum = int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1);
        const int2 offsets[4] = {int2(-1,0), int2(1,0), int2(0,-1), int2(0,1)};
        float3 difference = float3(0.0f);
        for (uint i = 0; i < 4; i++) difference += center.rgb - inputTexture.read(uint2(clamp(p + offsets[i], int2(0), maximum))).rgb;
        result.rgb += sharpness * difference;
    }
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
