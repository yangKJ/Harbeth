//
//  C7HSL.metal
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

#include <metal_stdlib>
using namespace metal;

// RGB到HSL转换
float3 rgbToHsl(float3 rgb) {
    float maxVal = max(max(rgb.r, rgb.g), rgb.b);
    float minVal = min(min(rgb.r, rgb.g), rgb.b);
    float delta = maxVal - minVal;
    
    float3 hsl;
    
    hsl.z = (maxVal + minVal) / 2.0;
    if (delta == 0.0) {
        hsl.x = 0.0;
        hsl.y = 0.0;
    } else {
        hsl.y = delta / (1.0 - abs(2.0 * hsl.z - 1.0));
        if (maxVal == rgb.r) {
            hsl.x = 60.0 * fmod(((rgb.g - rgb.b) / delta), 6.0);
        } else if (maxVal == rgb.g) {
            hsl.x = 60.0 * ((rgb.b - rgb.r) / delta + 2.0);
        } else {
            hsl.x = 60.0 * ((rgb.r - rgb.g) / delta + 4.0);
        }
        if (hsl.x < 0.0) {
            hsl.x += 360.0;
        }
    }
    
    return hsl;
}

// HSL到RGB转换
float3 hslToRgb(float3 hsl) {
    float C = (1.0 - abs(2.0 * hsl.z - 1.0)) * hsl.y;
    float X = C * (1.0 - abs(fmod(hsl.x / 60.0, 2.0) - 1.0));
    float m = hsl.z - C / 2.0;
    
    float3 rgb;
    
    if (hsl.x >= 0.0 && hsl.x < 60.0) {
        rgb = float3(C, X, 0.0);
    } else if (hsl.x >= 60.0 && hsl.x < 120.0) {
        rgb = float3(X, C, 0.0);
    } else if (hsl.x >= 120.0 && hsl.x < 180.0) {
        rgb = float3(0.0, C, X);
    } else if (hsl.x >= 180.0 && hsl.x < 240.0) {
        rgb = float3(0.0, X, C);
    } else if (hsl.x >= 240.0 && hsl.x < 300.0) {
        rgb = float3(X, 0.0, C);
    } else {
        rgb = float3(C, 0.0, X);
    }
    
    return rgb + m;
}

kernel void C7HSL(texture2d<half, access::write> outputTexture [[texture(0)]],
                  texture2d<half, access::read> inputTexture [[texture(1)]],
                  constant float *hue [[buffer(0)]],
                  constant float *saturation [[buffer(1)]],
                  constant float *lightness [[buffer(2)]],
                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    float3 rgb = float3(inColor.r, inColor.g, inColor.b);
    
    float hueAdjust = *hue;
    float saturationAdjust = *saturation;
    float lightnessAdjust = *lightness;
    
    float3 hsl = rgbToHsl(rgb);
    
    hsl.x += hueAdjust;
    if (hsl.x < 0.0) {
        hsl.x += 360.0;
    } else if (hsl.x >= 360.0) {
        hsl.x -= 360.0;
    }
    
    hsl.y += saturationAdjust;
    hsl.y = clamp(hsl.y, 0.0, 1.0);
    hsl.z += lightnessAdjust;
    hsl.z = clamp(hsl.z, 0.0, 1.0);
    
    float3 outRgb = hslToRgb(hsl);
    
    half4 outColor = half4(half3(outRgb), inColor.a);
    
    outputTexture.write(outColor, grid);
}
