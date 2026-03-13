//
//  C7HighlightShadowTone.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

float4 hst_convertFromRGBToYIQ(float4 src) {
    float3 pix2;
    float4 pix = src;
    pix.xyz = sqrt(fmax(pix.xyz, 0.000000e+00f));
    pix2 = ((pix.x* float3(2.990000e-01f, 5.960000e-01f, 2.120000e-01f))+ (pix.y* float3(5.870000e-01f, -2.755000e-01f, -5.230000e-01f)))+ (pix.z* float3(1.140000e-01f, -3.210000e-01f, 3.110000e-01f));
    return float4(pix2, pix.w);
}

float4 hst_convertFromYIQToRGB(float4 src) {
    float4 color, pix;
    pix = src;
    color.xyz = ((pix.x* float3(1.000480e+00f, 9.998640e-01f, 9.994460e-01f))+ (pix.y* float3(9.555580e-01f, -2.715450e-01f, -1.108030e+00f)))+ (pix.z* float3(6.195490e-01f, -6.467860e-01f, 1.705420e+00f));
    color.xyz = fmax(color.xyz, float3(0.000000e+00f));
    color.xyz = color.xyz* color.xyz;
    color.w = pix.w;
    return color;
}

kernel void C7HighlightShadowTone(texture2d<half, access::write> outputTexture [[texture(0)]],
                                  texture2d<half, access::read> inputTexture [[texture(1)]],
                                  texture2d<half, access::read> blurTexture [[texture(2)]],
                                  constant float *shadows [[buffer(0)]],
                                  constant float *highlights [[buffer(1)]],
                                  constant float *midtones [[buffer(2)]],
                                  constant float *contrast [[buffer(3)]],
                                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half4 blurColor = blurTexture.read(grid);
    
    float4 source = float4(float3(inColor.rgb), float(inColor.a));
    float4 blur = float4(float3(blurColor.rgb), float(blurColor.a));
    float4 sourceYIQ = hst_convertFromRGBToYIQ(source);
    float4 blurYIQ = hst_convertFromRGBToYIQ(blur);
    
    float shadowAmount = *shadows;
    float highlightAmount = *highlights;
    float midtoneAmount = *midtones;
    float contrastAmount = *contrast;
    
    float highlights_sign_negated = copysign(1.0, -highlightAmount);
    float shadows_sign = copysign(1.0f, shadowAmount);
    constexpr float compress = 0.5;
    constexpr float low_approximation = 0.01f;
    constexpr float shadowColor = 1.0;
    constexpr float highlightColor = 1.0;
    
    float tb0 = 1.0 - blurYIQ.x;
    
    if (tb0 < 1.0 - compress && highlightAmount != 0.0) {
        float highlights2 = highlightAmount * highlightAmount;
        float highlights_xform = min(1.0f - tb0 / (1.0f - compress), 1.0f);
        while (highlights2 > 0.0f) {
            float lref, href;
            float chunk, optrans;
            float la = sourceYIQ.x;
            float la_abs;
            float la_inverted = 1.0f - la;
            float la_inverted_abs;
            float lb = (tb0 - 0.5f) * highlights_sign_negated * sign(la_inverted) + 0.5f;
            
            la_abs = abs(la);
            lref = copysign(la_abs > low_approximation ? 1.0f / la_abs : 1.0f / low_approximation, la);
            
            la_inverted_abs = abs(la_inverted);
            href = copysign(la_inverted_abs > low_approximation ? 1.0f / la_inverted_abs : 1.0f / low_approximation, la_inverted);
            
            chunk = highlights2 > 1.0f ? 1.0f : highlights2;
            optrans = chunk * highlights_xform;
            highlights2 -= 1.0f;
            
            sourceYIQ.x = la * (1.0 - optrans) + (la > 0.5f ? 1.0f - (1.0f - 2.0f * (la - 0.5f)) * (1.0f - lb) : 2.0f * la * lb) * optrans;
            
            sourceYIQ.y = sourceYIQ.y * (1.0f - optrans) + sourceYIQ.y * (sourceYIQ.x * lref * (1.0f - highlightColor) + (1.0f - sourceYIQ.x) * href * highlightColor) * optrans;
            
            sourceYIQ.z = sourceYIQ.z * (1.0f - optrans) + sourceYIQ.z * (sourceYIQ.x * lref * (1.0f - highlightColor) + (1.0f - sourceYIQ.x) * href * highlightColor) * optrans;
        }
    }
    
    if (tb0 > compress && shadowAmount != 0.0) {
        float shadows2 = shadowAmount * shadowAmount;
        float shadows_xform = min(tb0 / (1.0f - compress) - compress / (1.0f - compress), 1.0f);
        
        while (shadows2 > 0.0f) {
            float lref, href;
            float chunk, optrans;
            float la = sourceYIQ.x;
            float la_abs;
            float la_inverted = 1.0f - la;
            float la_inverted_abs;
            float lb = (tb0 - 0.5f) * shadows_sign * sign(la_inverted) + 0.5f;
            
            la_abs = abs(la);
            lref = copysign(la_abs > low_approximation ? 1.0f / la_abs : 1.0f / low_approximation, la);
            
            la_inverted_abs = abs(la_inverted);
            href = copysign(la_inverted_abs > low_approximation ? 1.0f / la_inverted_abs : 1.0f / low_approximation, la_inverted);
            
            chunk = shadows2 > 1.0f ? 1.0f : shadows2;
            optrans = chunk * shadows_xform;
            shadows2 -= 1.0f;
            
            sourceYIQ.x = la * (1.0 - optrans) + (la > 0.5f ? 1.0f - (1.0f - 2.0f * (la - 0.5f)) * (1.0f - lb) : 2.0f * la * lb) * optrans;
            
            sourceYIQ.y = sourceYIQ.y * (1.0f - optrans) + sourceYIQ.y * (sourceYIQ.x * lref * shadowColor + (1.0f - sourceYIQ.x) * href * (1.0f - shadowColor)) * optrans;
            
            sourceYIQ.z = sourceYIQ.z * (1.0f - optrans) + sourceYIQ.z * (sourceYIQ.x * lref * shadowColor + (1.0f - sourceYIQ.x) * href * (1.0f - shadowColor)) * optrans;
        }
    }
    
    if (midtoneAmount != 0.0) {
        float midtoneAdjustment = abs(sourceYIQ.x - 0.5f) * abs(midtoneAmount) * 0.3f;
        if (midtoneAmount > 0.0) {
            sourceYIQ.x += midtoneAdjustment;
        } else {
            sourceYIQ.x -= midtoneAdjustment;
        }
    }
    
    if (contrastAmount != 0.0) {
        float contrastFactor = 1.0f + contrastAmount * 0.5f;
        sourceYIQ.x = ((sourceYIQ.x - 0.5f) * contrastFactor) + 0.5f;
    }
    
    float4 result = hst_convertFromYIQToRGB(sourceYIQ);
    const half4 outColor = half4(half3(result.rgb), inColor.a);
    
    outputTexture.write(outColor, grid);
}
