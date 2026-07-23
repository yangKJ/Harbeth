//
//  C7SelectiveHSL.metal
//  Harbeth
//
//  Created by Condy on 2026/7/23.
//

#include <metal_stdlib>
using namespace metal;

static float3 c7SelectiveRGBToHSL(float3 rgb) {
    const float maximum = max(max(rgb.r, rgb.g), rgb.b);
    const float minimum = min(min(rgb.r, rgb.g), rgb.b);
    const float delta = maximum - minimum;
    const float lightness = (maximum + minimum) * 0.5;
    if (delta < 0.00001) return float3(0.0, 0.0, lightness);

    const float saturation = delta / max(0.00001, 1.0 - abs(2.0 * lightness - 1.0));
    float hue;
    if (maximum == rgb.r) {
        hue = 60.0 * fmod((rgb.g - rgb.b) / delta, 6.0);
    } else if (maximum == rgb.g) {
        hue = 60.0 * ((rgb.b - rgb.r) / delta + 2.0);
    } else {
        hue = 60.0 * ((rgb.r - rgb.g) / delta + 4.0);
    }
    if (hue < 0.0) hue += 360.0;
    return float3(hue, saturation, lightness);
}

static float3 c7SelectiveHSLToRGB(float3 hsl) {
    const float chroma = (1.0 - abs(2.0 * hsl.z - 1.0)) * hsl.y;
    const float secondary = chroma * (1.0 - abs(fmod(hsl.x / 60.0, 2.0) - 1.0));
    const float offset = hsl.z - chroma * 0.5;
    float3 rgb;
    if (hsl.x < 60.0) rgb = float3(chroma, secondary, 0.0);
    else if (hsl.x < 120.0) rgb = float3(secondary, chroma, 0.0);
    else if (hsl.x < 180.0) rgb = float3(0.0, chroma, secondary);
    else if (hsl.x < 240.0) rgb = float3(0.0, secondary, chroma);
    else if (hsl.x < 300.0) rgb = float3(secondary, 0.0, chroma);
    else rgb = float3(chroma, 0.0, secondary);
    return rgb + offset;
}

static float c7SelectiveCenter(uint index) {
    switch (index) {
        case 0: return 0.0;
        case 1: return 30.0;
        case 2: return 60.0;
        case 3: return 120.0;
        case 4: return 180.0;
        case 5: return 240.0;
        case 6: return 275.0;
        default: return 320.0;
    }
}

static float c7SelectiveWidth(uint index) {
    switch (index) {
        case 0: return 32.0;
        case 1: return 30.0;
        case 2: return 38.0;
        case 3: return 50.0;
        case 4: return 45.0;
        case 5: return 45.0;
        case 6: return 38.0;
        default: return 42.0;
    }
}

kernel void C7SelectiveHSL(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *adjustments [[buffer(0)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 source = float3(input.rgb);
    const float3 boundedSource = clamp(source, 0.0, 1.0);
    float3 hsl = c7SelectiveRGBToHSL(boundedSource);
    float3 adjustment = float3(0.0);
    float totalWeight = 0.0;
    const float chromaWeight = smoothstep(0.015, 0.12, hsl.y);

    for (uint index = 0; index < 8; ++index) {
        const float rawDistance = abs(hsl.x - c7SelectiveCenter(index));
        const float distance = min(rawDistance, 360.0 - rawDistance);
        const float width = c7SelectiveWidth(index);
        const float weight = (1.0 - smoothstep(width * 0.45, width, distance)) * chromaWeight;
        adjustment += float3(
            adjustments[index * 3],
            adjustments[index * 3 + 1],
            adjustments[index * 3 + 2]
        ) * weight;
        totalWeight += weight;
    }

    adjustment /= max(1.0, totalWeight);
    hsl.x = fmod(hsl.x + adjustment.x * 60.0 + 360.0, 360.0);
    hsl.y = clamp(hsl.y + adjustment.y, 0.0, 1.0);
    hsl.z = clamp(hsl.z + adjustment.z, 0.0, 1.0);
    const float3 output = c7SelectiveHSLToRGB(hsl) + source - boundedSource;
    outputTexture.write(half4(half3(output), input.a), grid);
}
