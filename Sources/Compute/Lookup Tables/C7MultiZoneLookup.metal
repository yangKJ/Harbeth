//
//  C7MultiZoneLookup.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

float4 sampleLookupTable(texture2d<half, access::sample> lookupTexture, float3 color) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 lookup;
    lookup.y = 0.5;
    
    float4 lookupColor;
    lookup.x = color.r;
    lookupColor.r = lookupTexture.sample(s, lookup).r;
    
    lookup.x = color.g;
    lookupColor.g = lookupTexture.sample(s, lookup).g;
    
    lookup.x = color.b;
    lookupColor.b = lookupTexture.sample(s, lookup).b;
    
    lookupColor.a = 1.0;
    return lookupColor;
}

struct WeightResult {
    float shadow;
    float midtone;
    float highlight;
};

WeightResult multiZoneCalculateWeights(float luminance, float shadowThreshold, float highlightThreshold, float transitionWidth) {
    float shadow = min(shadowThreshold, highlightThreshold - 0.01);
    float highlight = max(highlightThreshold, shadow + 0.01);
    
    float shadowEnd = shadow + transitionWidth;
    float highlightStart = highlight - transitionWidth;
    
    WeightResult result;
    
    if (luminance <= shadow) {
        result.shadow = 1.0;
        result.midtone = 0.0;
        result.highlight = 0.0;
    } else if (luminance >= highlight) {
        result.shadow = 0.0;
        result.midtone = 0.0;
        result.highlight = 1.0;
    } else if (luminance > shadow && luminance < highlight) {
        if (luminance <= shadowEnd) {
            float t = (luminance - shadow) / (transitionWidth * 2.0);
            result.shadow = 1.0 - t;
            result.midtone = t;
            result.highlight = 0.0;
        } else if (luminance >= highlightStart) {
            float t = (luminance - highlightStart) / (transitionWidth * 2.0);
            result.shadow = 0.0;
            result.midtone = 1.0 - t;
            result.highlight = t;
        } else {
            result.shadow = 0.0;
            result.midtone = 1.0;
            result.highlight = 0.0;
        }
    } else {
        result.shadow = 0.0;
        result.midtone = 1.0;
        result.highlight = 0.0;
    }
    
    return result;
}

kernel void C7MultiZoneLookup(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> shadowLookupTexture [[texture(2)]],
                              texture2d<half, access::sample> midtoneLookupTexture [[texture(3)]],
                              texture2d<half, access::sample> highlightLookupTexture [[texture(4)]],
                              constant float *parameters [[buffer(0)]],
                              uint2 grid [[thread_position_in_grid]]) {
    float shadowThreshold = parameters[0];
    float highlightThreshold = parameters[1];
    float transitionWidth = parameters[2];
    
    const half4 inColor = inputTexture.read(grid);
    float3 color = float3(inColor.r, inColor.g, inColor.b);
    
    float luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    
    WeightResult weights = multiZoneCalculateWeights(luminance, shadowThreshold, highlightThreshold, transitionWidth);
    
    float4 shadowColor = sampleLookupTable(shadowLookupTexture, color);
    float4 midtoneColor = sampleLookupTable(midtoneLookupTexture, color);
    float4 highlightColor = sampleLookupTable(highlightLookupTexture, color);
    float4 finalColor = shadowColor * weights.shadow + midtoneColor * weights.midtone + highlightColor * weights.highlight;
    half4 outColor;
    outColor.r = half(finalColor.r);
    outColor.g = half(finalColor.g);
    outColor.b = half(finalColor.b);
    outColor.a = inColor.a;
    
    outputTexture.write(outColor, grid);
}
