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
                           constant float *temperature_ [[buffer(0)]],
                           constant float *tint [[buffer(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 RGBtoYIQ = half3x3({0.299, 0.587, 0.114}, {0.596, -0.274, -0.322}, {0.212, -0.523, 0.311});
    const half3x3 YIQtoRGB = half3x3({1.000, 0.956, 0.621}, {1.000, -0.272, -0.647}, {1.000, -1.105, 1.702});
    
    half3 yiq = RGBtoYIQ * inColor.rgb;
    yiq.b = clamp(yiq.b + half(*tint/100) * 0.5226 * 0.1, -0.5226, 0.5226);
    const half3 rgb = YIQtoRGB * yiq;
    
    const half3 warm = half3(0.93, 0.54, 0.0);
    // Overlay blend, HDR-safe: extrapolate linearly outside [0,1].
    half3 blended;
    for (int i = 0; i < 3; i++) {
        half v = rgb[i];
        half w = warm[i];
        if (v < 0.0h || v > 1.0h) {
            if (v < 0.0h) {
                blended[i] = v * (2.0h * w);
            } else {
                blended[i] = 1.0h + 2.0h * (1.0h - w) * (v - 1.0h);
            }
        } else if (v < 0.5h) {
            blended[i] = 2.0h * v * w;
        } else {
            blended[i] = 1.0h - 2.0h * (1.0h - v) * (1.0h - w);
        }
    }
    const half r = blended.r;
    const half g = blended.g;
    const half b = blended.b;
    
    half temperature = half(*temperature_);
    temperature = temperature < 5000 ? 0.0004 * (temperature - 5000) : 0.00006 * (temperature - 5000);
    const half4 outColor = half4(mix(rgb, half3(r, g, b), temperature), inColor.a);
    outputTexture.write(outColor, grid);
}
