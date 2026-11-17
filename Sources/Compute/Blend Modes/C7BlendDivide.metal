// 由 Condy 维护。零分母采用饱和端点，保留原有预乘 legacy 分段公式。
#include <metal_stdlib>
using namespace metal;
kernel void C7BlendDivide(texture2d<float, access::write> outputTexture [[texture(0)]],
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
        float4 divided;
        for (uint c=0; c<3; c++) {
            const float remainder = overlay[c]*(1.0f-input.a)+input[c]*(1.0f-overlay.a);
            if (overlay.a == 0.0f || overlay[c] == 0.0f || input[c]/overlay[c] > input.a/overlay.a) {
                divided[c] = overlay.a*input.a+remainder;
            } else {
                divided[c] = input[c]*overlay.a*overlay.a/overlay[c]+remainder;
            }
        }
        divided.a = overlay.a+input.a-overlay.a*input.a;
        result = mix(input,divided,clamp(intensity,0.0f,1.0f));
    }
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result,grid);
}
