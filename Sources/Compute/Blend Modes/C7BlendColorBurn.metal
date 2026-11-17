// 由 Condy 维护。保留非零分母的 legacy 公式，仅定义有限端点。
#include <metal_stdlib>
using namespace metal;
kernel void C7BlendColorBurn(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             texture2d<float, access::sample> inputTexture2 [[texture(2)]],
                             constant float &intensity [[buffer(0)]],
                             constant float &halfOutput [[buffer(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 input = inputTexture.read(grid);
    float4 result = input;
    if (isfinite(intensity) && intensity > 0.0f) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
        const float2 uv = (float2(grid)+0.5f)/float2(outputTexture.get_width(),outputTexture.get_height());
        const float4 overlay = inputTexture2.sample(s,uv);
        float4 burned;
        for (uint c=0; c<4; c++) {
            burned[c] = overlay[c] == 0.0f ? (input[c] == 1.0f ? 1.0f : 0.0f) : 1.0f - (1.0f-input[c])/overlay[c];
        }
        result = mix(input,burned,clamp(intensity,0.0f,1.0f));
    }
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result,grid);
}
