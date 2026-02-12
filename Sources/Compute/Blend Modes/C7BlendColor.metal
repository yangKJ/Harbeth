//
//  C7BlendColor.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendColor(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                         constant float *intensity [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    float inLuminance = dot(inColor.rgb, half3(0.299, 0.587, 0.114));
    half3 overlayGrayscale = half3(dot(overlay.rgb, half3(0.299, 0.587, 0.114)));
    half3 colorDifference = overlay.rgb - overlayGrayscale;
    
    outColor.rgb = half3(inLuminance) + colorDifference;
    outColor.a = inColor.a;
    outColor.rgb = clamp(outColor.rgb, half3(0.0), half3(1.0));
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
