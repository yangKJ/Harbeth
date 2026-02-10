//
//  C7VignetteBlend.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

half3 vignetteBlendOverlay(half3 base, half3 blend, half alpha) {
    bool3 condition = base < 0.5h;
    half3 trueValue = 2.0h * base * blend;
    half3 falseValue = 1.0h - 2.0h * (1.0h - base) * (1.0h - blend);
    half3 result = select(falseValue, trueValue, condition);
    return mix(base, result, alpha);
}

half3 vignetteBlendSoftLight(half3 base, half3 blend, half alpha) {
    bool3 condition = base < 0.5h;
    half3 trueValue = 2.0h * base;
    half3 falseValue = 1.0h - 2.0h * (1.0h - base) * (1.0h - base);
    half3 blendedValue = select(falseValue, trueValue, condition);
    half3 result = base * (1.0h - blend) + blend * blendedValue;
    return mix(base, result, alpha);
}

kernel void C7VignetteBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *centerX [[buffer(0)]],
                            constant float *centerY [[buffer(1)]],
                            constant float *start [[buffer(2)]],
                            constant float *end [[buffer(3)]],
                            constant float *blendMode [[buffer(4)]],
                            constant float3 *colorVector [[buffer(5)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half2 center = half2(*centerX, *centerY);
    const float dd = distance(textureCoordinate, float2(center));
    const half percent = smoothstep(*start, *end, dd);
    
    half3 vignetteColor = half3(*colorVector);
    half3 resultColor = inColor.rgb;
    
    switch (int(*blendMode)) {
        case 0:
            resultColor = mix(inColor.rgb, vignetteColor, percent);
            break;
        case 1:
            resultColor = mix(inColor.rgb, inColor.rgb * vignetteColor, percent);
            break;
        case 2:
            resultColor = vignetteBlendOverlay(inColor.rgb, vignetteColor, percent);
            break;
        case 3:
            resultColor = vignetteBlendSoftLight(inColor.rgb, vignetteColor, percent);
            break;
        default:
            resultColor = mix(inColor.rgb, vignetteColor, percent);
            break;
    }
    
    const half4 outColor = half4(resultColor, inColor.a);
    outputTexture.write(outColor, grid);
}
