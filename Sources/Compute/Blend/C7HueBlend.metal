//
//  C7HueBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

half3 C7HueBlendSetlum(half3 c, half tt);
half3 C7HueBlendSetsat(half3 c, half s);

kernel void C7HueBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);

    const half4 overlay = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    const half tt = dot(overlay.rgb, half3(0.3, 0.59, 0.11));
    const half sat = max(max(inColor.r, inColor.g), inColor.b) - min(min(inColor.r, inColor.g), inColor.b);
    const half3 xxx = C7HueBlendSetsat(overlay.rgb, sat);
    const half4 outColor = half4(inColor.rgb * (1.0h - overlay.a) + C7HueBlendSetlum(xxx, tt) * overlay.a, inColor.a);
    
    outputTexture.write(outColor, grid);
}

half3 C7HueBlendSetlum(half3 c, half tt) {
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

half3 C7HueBlendSetsat(half3 c, half s) {
    if (c.r > c.g) {
        if (c.r > c.b) {
            if (c.g > c.b) {
                /* g is mid, b is min */
                c.g = ((c.g - c.b) * s) / (c.r - c.b);
                c.b = 0.0h;
            } else {
                /* b is mid, g is min */
                c.b = ((c.b - c.g) * s) / (c.r - c.g);
                c.g = 0.0h;
            }
            c.r = s;
        } else {
            /* b is max, r is mid, g is min */
            c.r = ((c.r - c.g) * s) / (c.b - c.g);
            c.b = s;
            c.r = 0.0h;
        }
    } else if (c.r > c.b) {
        /* g is max, r is mid, b is min */
        c.r = ((c.r - c.b) * s) / (c.g - c.b);
        c.g = s;
        c.b = 0.0h;
    } else if (c.g > c.b) {
        /* g is max, b is mid, r is min */
        c.b = ((c.b - c.r) * s) / (c.g - c.r);
        c.g = s;
        c.r = 0.0h;
    } else if (c.b > c.g) {
        /* b is max, g is mid, r is min */
        c.g = ((c.g - c.r) * s) / (c.b - c.r);
        c.b = s;
        c.r = 0.0h;
    } else {
        c = half3(0.0h);
    }
    return c;
}
