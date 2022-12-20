//
//  C7WhiteBalance.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7WhiteBalance(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *temperature [[buffer(0)]],
                           constant float *tint [[buffer(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 RGBtoYIQ = half3x3({0.299, 0.587, 0.114}, {0.596, -0.274, -0.322}, {0.212, -0.523, 0.311});
    const half3x3 YIQtoRGB = half3x3({1.000, 0.956, 0.621}, {1.000, -0.272, -0.647}, {1.000, -1.105, 1.702});
    
    half3 yiq = RGBtoYIQ * inColor.rgb;
    yiq.b = clamp(yiq.b + half(*tint) * 0.5226 * 0.1, -0.5226, 0.5226);
    const half3 rgb = YIQtoRGB * yiq;
    
    const half3 warm = half3(0.93, 0.54, 0.0);
    const half r = rgb.r < 0.5 ? (2.0 * rgb.r * warm.r) : (1.0 - 2.0 * (1.0 - rgb.r) * (1.0 - warm.r));
    const half g = rgb.g < 0.5 ? (2.0 * rgb.g * warm.g) : (1.0 - 2.0 * (1.0 - rgb.g) * (1.0 - warm.g));
    const half b = rgb.b < 0.5 ? (2.0 * rgb.b * warm.b) : (1.0 - 2.0 * (1.0 - rgb.b) * (1.0 - warm.b));
    
    const half4 outColor = half4(mix(rgb, half3(r, g, b), half(*temperature)), inColor.a);
    outputTexture.write(outColor, grid);
}
