//
//  C7LuminosityBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

half3 C7LuminosityBlendSetlum(half3 c, half tt);

kernel void C7LuminosityBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 overlay = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    const half tt = dot(overlay.rgb, half3(0.3, 0.59, 0.11));
    const half4 outColor = half4(inColor.rgb * (1.0h - overlay.a) + C7LuminosityBlendSetlum(inColor.rgb, tt) * overlay.a, inColor.a);
    
    outputTexture.write(outColor, grid);
}

half3 C7LuminosityBlendSetlum(half3 c, half tt) {
    half d = tt - dot(c, half3(0.3, 0.59, 0.11));
    c = c + half3(d);
    half l = dot(c, half3(0.3, 0.59, 0.11));
    half n = min(min(c.r, c.g), c.b);
    half x = max(max(c.r, c.g), c.b);
    if (n < 0.0h) {
        c.r = l + ((c.r - l) * l) / (l - n);
        c.g = l + ((c.g - l) * l) / (l - n);
        c.b = l + ((c.b - l) * l) / (l - n);
    }
    if (x > 1.0h) {
        c.r = l + ((c.r - l) * (1.0h - l)) / (x - l);
        c.g = l + ((c.g - l) * (1.0h - l)) / (x - l);
        c.b = l + ((c.b - l) * (1.0h - l)) / (x - l);
    }
    return c;
}
