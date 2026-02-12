//
//  C7BlendDarkerColor.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendDarkerColor(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> inputTexture [[texture(1)]],
                               texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                               constant float *intensity [[buffer(0)]],
                               uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    
    // Darker Color: 选择两个颜色中更暗的那个
    float inLuminance = dot(inColor.rgb, half3(0.299, 0.587, 0.114));
    float overlayLuminance = dot(overlay.rgb, half3(0.299, 0.587, 0.114));
    
    if (overlayLuminance < inLuminance) {
        outColor.rgb = overlay.rgb;
    } else {
        outColor.rgb = inColor.rgb;
    }
    outColor.a = inColor.a;
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
