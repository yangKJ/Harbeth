//
//  C7BlendSaturation.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendSaturation(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                              constant float *intensity [[buffer(0)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    
    // Saturation: 使用上层颜色的饱和度，底层颜色的色相和亮度
    half3 inGray = half3(dot(inColor.rgb, half3(0.299, 0.587, 0.114)));
    half3 overlayGray = half3(dot(overlay.rgb, half3(0.299, 0.587, 0.114)));
    half3 inSaturation = inColor.rgb - inGray;
    half3 overlaySaturation = overlay.rgb - overlayGray;
    
    outColor.rgb = inGray + overlaySaturation;
    outColor.a = inColor.a;
    outColor.rgb = clamp(outColor.rgb, half3(0.0), half3(1.0));
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
