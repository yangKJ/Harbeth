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

static float3 selectiveHSLColor(float3 source, constant float *adjustments, bool photographic) {
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
        adjustment += float3(adjustments[index * 3],
                             adjustments[index * 3 + 1],
                             adjustments[index * 3 + 2]) * weight;
        totalWeight += weight;
    }
    adjustment /= max(1.0, totalWeight);
    if (photographic) {
        // 色相在近黑区不稳定，渐隐选择避免把底噪重新染色。
        const float selection = smoothstep(0.02, 0.10, hsl.z);
        hsl.x = fmod(hsl.x + adjustment.x * selection * 60.0 + 360.0, 360.0);
        hsl.y = clamp(hsl.y + adjustment.y * selection, 0.0, 1.0);
        // 端点导数为零的明度偏移；对-1...1调整仍保持明度单调。
        const float response = 4.0 * hsl.z * hsl.z * (1.0 - hsl.z) * (1.0 - hsl.z);
        hsl.z = clamp(hsl.z + adjustment.z * response, 0.0, 1.0);
    } else {
        hsl.x = fmod(hsl.x + adjustment.x * 60.0 + 360.0, 360.0);
        hsl.y = clamp(hsl.y + adjustment.y, 0.0, 1.0);
        hsl.z = clamp(hsl.z + adjustment.z, 0.0, 1.0);
    }
    return c7SelectiveHSLToRGB(hsl) + source - boundedSource;
}

kernel void C7SelectiveHSL(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *adjustments [[buffer(0)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 output = selectiveHSLColor(float3(input.rgb), adjustments, false);
    outputTexture.write(half4(half3(output), input.a), grid);
}

kernel void C7SelectiveHSLPhotographic(texture2d<half, access::write> outputTexture [[texture(0)]],
                                       texture2d<half, access::read> inputTexture [[texture(1)]],
                                       constant float *adjustments [[buffer(0)]],
                                       uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 output = selectiveHSLColor(float3(input.rgb), adjustments, true);
    outputTexture.write(half4(half3(output), input.a), grid);
}

static float3 finishPhotographicNeutral(float3 styled, float3 neutralShadows, float3 neutralHighlights) {
    const float3 bounded = clamp(styled, 0.0, 1.0);
    const float chroma = max(max(bounded.r, bounded.g), bounded.b) - min(min(bounded.r, bounded.g), bounded.b);
    const float neutral = 1.0 - smoothstep(0.035, 0.20, chroma);
    const float luma = dot(bounded, float3(0.2126, 0.7152, 0.0722));
    const float shadow = smoothstep(0.015, 0.09, luma) * (1.0 - smoothstep(0.12, 0.37, luma));
    const float highlight = smoothstep(0.46, 0.72, luma) * min(1.0, (1.0 - luma) * 5.0);
    // 调整在显示色域端点衰减，回加原有扩展范围并恢复预乘覆盖。
    const float3 correction = neutral * (clamp(neutralShadows, -0.1, 0.1) * shadow + clamp(neutralHighlights, -0.1, 0.1) * highlight);
    const float3 delta = clamp(bounded + correction, 0.0, 1.0) - bounded;
    return styled + delta;
}

kernel void C7SelectiveHSLPhotographicNeutral(texture2d<half, access::write> outputTexture [[texture(0)]],
                                              texture2d<half, access::read> inputTexture [[texture(1)]],
                                              constant float *adjustments [[buffer(0)]],
                                              constant float3 &neutralShadows [[buffer(1)]],
                                              constant float3 &neutralHighlights [[buffer(2)]],
                                              uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    if (input.a <= 0.0h) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float alpha = float(input.a);
    const float3 styled = selectiveHSLColor(float3(input.rgb) / alpha, adjustments, true);
    const float3 color = finishPhotographicNeutral(styled, neutralShadows, neutralHighlights);
    outputTexture.write(half4(half3(color * alpha), input.a), grid);
}

static float3 applySelectiveHSLColorWindow(float3 styled, float4 hueEdges, float4 colorAdjustment, float3 windowTone) {
    if (all(colorAdjustment.zw == float2(0.0f)) && windowTone.z == 0.0f) return styled;
    const float3 bounded = clamp(styled, 0.0f, 1.0f);
    const float chroma = max(max(bounded.r, bounded.g), bounded.b) - min(min(bounded.r, bounded.g), bounded.b);
    const float chromaWeight = smoothstep(colorAdjustment.x, colorAdjustment.y, chroma);
    if (chromaWeight > 0.0f) {
        float3 hsl = c7SelectiveRGBToHSL(bounded);
        const float hueWeight = smoothstep(hueEdges.x, hueEdges.y, hsl.x)
            * (1.0f - smoothstep(hueEdges.z, hueEdges.w, hsl.x));
        const float saturationWeight = windowTone.x < windowTone.y
            ? 1.0f - smoothstep(windowTone.x, windowTone.y, hsl.y)
            : 1.0f;
        const float weight = hueWeight * chromaWeight * saturationWeight;
        if (weight > 0.0f) {
            hsl.x += colorAdjustment.z * weight;
            if (hsl.x < 0.0f) hsl.x += 360.0f;
            else if (hsl.x >= 360.0f) hsl.x -= 360.0f;
            hsl.y = clamp(hsl.y + colorAdjustment.w * weight, 0.0f, 1.0f);
            hsl.z = clamp(hsl.z + windowTone.z * weight, 0.0f, 1.0f);
            styled += c7SelectiveHSLToRGB(hsl) - bounded;
        }
    }
    return styled;
}

kernel void C7SelectiveHSLPhotographicNeutralColorWindow(texture2d<half, access::write> outputTexture [[texture(0)]],
                                                         texture2d<half, access::read> inputTexture [[texture(1)]],
                                                         constant float *adjustments [[buffer(0)]],
                                                         constant float3 &neutralShadows [[buffer(1)]],
                                                         constant float3 &neutralHighlights [[buffer(2)]],
                                                         constant float4 &hueEdges [[buffer(3)]],
                                                         constant float4 &colorAdjustment [[buffer(4)]],
                                                         constant float3 &windowTone [[buffer(5)]],
                                                         uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    if (input.a <= 0.0h) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float alpha = float(input.a);
    float3 styled = selectiveHSLColor(float3(input.rgb) / alpha, adjustments, true);
    styled = applySelectiveHSLColorWindow(styled, hueEdges, colorAdjustment, windowTone);
    const float3 color = finishPhotographicNeutral(styled, neutralShadows, neutralHighlights);
    outputTexture.write(half4(half3(color * alpha), input.a), grid);
}

static float3 neutralizeCoolHighlights(float3 source, float4 tone, float4 chroma, float4 cyanAndAmount,
                                       float4 upperTone, float upperGreenAmount, float4 blueClip) {
    const float3 bounded = clamp(source, 0.0f, 1.0f);
    const float span = bounded.b - bounded.r;
    if (bounded.g <= tone.x || bounded.b <= tone.z || span <= chroma.x || span >= chroma.w + upperTone.w + blueClip.w) return source;

    const float cyan = (bounded.g - bounded.r) / span;
    if (cyan <= cyanAndAmount.x) return source;
    const float green = smoothstep(tone.x, tone.y, bounded.g);
    // 在较低亮度保护有意保留的浅青，随亮度回到原高光色度范围。
    const float chromaScale = mix(cyanAndAmount.w, 1.0f, green * green);
    const float expansion = upperTone.w > 0.0f && bounded.g > upperTone.x
        ? smoothstep(upperTone.x, upperTone.y, bounded.g) : 0.0f;
    const float fadeStart = chroma.z * chromaScale;
    const float fadeEnd = chroma.w * chromaScale;
    const float ordinaryUpperEnd = fadeEnd + upperTone.w * expansion;
    const float clipped = blueClip.w > 0.0f && ordinaryUpperEnd > fadeEnd && bounded.b > blueClip.x && span > fadeEnd
        ? green * smoothstep(blueClip.x, blueClip.y, bounded.b) * smoothstep(fadeEnd, ordinaryUpperEnd, span)
        : 0.0f;
    const float upperEnd = ordinaryUpperEnd + blueClip.w * clipped;
    if (span >= upperEnd) return source;
    const float lowerRamp = green * smoothstep(tone.z, tone.w, bounded.b) * smoothstep(chroma.x, chroma.y, span);
    const float hueWeight = smoothstep(cyanAndAmount.x, cyanAndAmount.y, cyan);
    const float fade = smoothstep(fadeStart, fadeEnd, span);
    const float weight = lowerRamp * (1.0f - fade) * hueWeight * cyanAndAmount.z;
    // 仅增加较低通道，保留蓝通道及原有扩展高光。
    const float3 channels = max(bounded.b - bounded, 0.0f);
    const float3 adjusted = source + weight * channels;
    if (expansion <= 0.0f || fade <= 0.0f) return adjusted;
    const float upperStart = fadeStart + upperTone.z * expansion + blueClip.z * clipped;
    const float upperFade = smoothstep(upperStart, upperEnd, span);
    const float added = lowerRamp * max(0.0f, fade - upperFade) * hueWeight * cyanAndAmount.z;
    return adjusted + added * channels * float3(1.0f, upperGreenAmount, 0.0f);
}

kernel void C7SelectiveHSLPhotographicHighlights(texture2d<half, access::write> outputTexture [[texture(0)]],
                                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                                constant float *adjustments [[buffer(0)]],
                                                constant float3 &neutralShadows [[buffer(1)]],
                                                constant float3 &neutralHighlights [[buffer(2)]],
                                                constant float4 &hueEdges [[buffer(3)]],
                                                constant float4 &colorAdjustment [[buffer(4)]],
                                                constant float3 &windowTone [[buffer(5)]],
                                                constant float4 &highlightToneEdges [[buffer(6)]],
                                                constant float4 &highlightChromaEdges [[buffer(7)]],
                                                constant float4 &highlightCyanAndAmount [[buffer(8)]],
                                                constant float4 &highlightUpperTone [[buffer(9)]],
                                                constant float &highlightUpperGreenAmount [[buffer(10)]],
                                                constant float4 &highlightBlueClip [[buffer(11)]],
                                                uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const half4 input = inputTexture.read(grid);
    if (input.a <= 0.0h) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float alpha = float(input.a);
    float3 color = selectiveHSLColor(float3(input.rgb) / alpha, adjustments, true);
    color = applySelectiveHSLColorWindow(color, hueEdges, colorAdjustment, windowTone);
    color = finishPhotographicNeutral(color, neutralShadows, neutralHighlights);
    color = neutralizeCoolHighlights(color, highlightToneEdges, highlightChromaEdges, highlightCyanAndAmount,
                                     highlightUpperTone, highlightUpperGreenAmount, highlightBlueClip);
    outputTexture.write(half4(half3(color * alpha), input.a), grid);
}

static float3 labWindowLinearRGB(float light, float2 chroma) {
    const float fy = (light + 16.0f) / 116.0f;
    const float3 f = float3(fy + chroma.x / 500.0f, fy, fy - chroma.y / 200.0f);
    const float3 xyz = select((f - 16.0f / 116.0f) / 7.787f, f * f * f, f > 0.2068966f)
        * float3(0.95047f, 1.0f, 1.08883f);
    return float3(dot(xyz, float3(3.24048134f, -1.53715152f, -0.49853633f)),
                  dot(xyz, float3(-0.96925495f, 1.87599f, 0.04155593f)),
                  dot(xyz, float3(0.05564664f, -0.20404134f, 1.05731107f)));
}

static bool labWindowInGamut(float3 rgb) {
    return all(rgb >= 0.0f) && all(rgb <= 1.0f);
}

static float3 applyLabColorWindow(float3 rgb, float4 hueEdges, float4 edges, float3 low, float3 high) {
    if (!labWindowInGamut(rgb) || all(rgb == rgb.rrr)) return rgb;
    const float3 linear = select(rgb / 12.92f, pow((rgb + 0.055f) / 1.055f, 2.4f), rgb > 0.04045f);
    const float3 xyz = float3(dot(linear, float3(0.412453f, 0.35758f, 0.180423f)),
                              dot(linear, float3(0.212671f, 0.71516f, 0.072169f)),
                              dot(linear, float3(0.019334f, 0.119193f, 0.950227f)))
        / float3(0.95047f, 1.0f, 1.08883f);
    // Lab 中 b* 的符号与归一化 Y-Z 相同，无需为不在目标半圈内的像素计算明度。
    if ((hueEdges.x >= 180.0f && xyz.y > xyz.z) || (hueEdges.w <= 180.0f && xyz.y < xyz.z)) return rgb;
    const float3 f = select(7.787f * xyz + 16.0f / 116.0f, pow(xyz, 1.0f / 3.0f), xyz > 0.008856f);
    const float light = 116.0f * f.y - 16.0f;
    const float2 ab = float2(500.0f * (f.x - f.y), 200.0f * (f.y - f.z));
    const float chroma = length(ab);
    if (light >= edges.w || chroma <= edges.x) return rgb;
    const float angle = atan2(ab.y, ab.x) * 57.295779513f;
    const float hue = angle < 0.0f ? angle + 360.0f : angle;
    const float weight = smoothstep(hueEdges.x, hueEdges.y, hue)
        * (1.0f - smoothstep(hueEdges.z, hueEdges.w, hue))
        * smoothstep(edges.x, edges.y, chroma)
        * (1.0f - smoothstep(edges.z, edges.w, light));
    if (weight <= 0.0f) return rgb;
    const float2 axis = ab / chroma;
    const float2 shifts = mix(low.yz, high.yz, clamp((light - low.x) / (high.x - low.x), 0.0f, 1.0f));
    const float2 delta = weight * (shifts.x * axis + shifts.y * float2(-axis.y, axis.x));
    if (all(delta == 0.0f)) return rgb;
    float3 output = labWindowLinearRGB(light, ab + delta);
    if (!labWindowInGamut(output)) {
        // 色域外逐步减弱位移，保持同一明度及变化方向。
        float lower = 0.0f;
        float upper = 1.0f;
        for (uint step = 0; step < 9; ++step) {
            const float amount = (lower + upper) * 0.5f;
            if (labWindowInGamut(labWindowLinearRGB(light, ab + delta * amount))) lower = amount;
            else upper = amount;
        }
        if (lower == 0.0f) return rgb;
        output = labWindowLinearRGB(light, ab + delta * lower);
    }
    return select(12.92f * output, 1.055f * pow(output, 1.0f / 2.4f) - 0.055f, output > 0.0031308f);
}

static float3 applyLabCorrections(float3 rgb, constant float *parameters) {
    const uint count = min(uint(parameters[0]), 9u);
    if (count == 0 || !all(isfinite(rgb)) || any(rgb > 1.0f)) return rgb;
    // 以可显示颜色选择窗口。仅对命中的负通道做色域映射，扩展高光继续透传。
    const float3 bounded = max(rgb, 0.0f);
    if (all(bounded == bounded.rrr)) return rgb;
    const float3 linear = select(bounded / 12.92f, pow((bounded + 0.055f) / 1.055f, 2.4f), bounded > 0.04045f);
    const float3 xyz = float3(dot(linear, float3(0.412453f, 0.35758f, 0.180423f)),
                              dot(linear, float3(0.212671f, 0.71516f, 0.072169f)),
                              dot(linear, float3(0.019334f, 0.119193f, 0.950227f)))
        / float3(0.95047f, 1.0f, 1.08883f);
    const float3 f = select(7.787f * xyz + 16.0f / 116.0f, pow(xyz, 1.0f / 3.0f), xyz > 0.008856f);
    const float light = 116.0f * f.y - 16.0f;
    const float2 ab = float2(500.0f * (f.x - f.y), 200.0f * (f.y - f.z));
    const float chroma = length(ab);
    if (chroma <= 0.0f) return rgb;
    const float angle = atan2(ab.y, ab.x);
    const float hue = (angle < 0.0f ? angle + 6.283185307f : angle) * 57.295779513f;
    float3 change = 0.0f;
    for (uint index = 0; index < count; index++) {
        constant float *window = parameters + 1 + index * 15;
        const float minimumLightness = window[12] > window[11] ? smoothstep(window[11], window[12], light) : 1.0f;
        const float weight = smoothstep(window[0], window[1], hue)
            * (1.0f - smoothstep(window[2], window[3], hue))
            * smoothstep(window[4], window[5], chroma)
            * (1.0f - smoothstep(window[6], window[7], light));
        const float chromaFade = window[14] > window[13] ? 1.0f - smoothstep(window[13], window[14], chroma) : 1.0f;
        change += (weight * minimumLightness * chromaFade) * float3(window[8], window[9], window[10]);
    }
    if (all(change == 0.0f)) return rgb;
    const float target = angle + change.z * 0.01745329252f;
    const float2 deltaAB = max(0.0f, chroma + change.y) * float2(cos(target), sin(target)) - ab;
    float3 output = labWindowLinearRGB(light + change.x, ab + deltaAB);
    if (!labWindowInGamut(output)) {
        // 联合收敛明度与色度位移，避免逐通道裁剪造成色相跳变。
        float lower = 0.0f;
        float upper = 1.0f;
        for (uint step = 0; step < 9; ++step) {
            const float amount = (lower + upper) * 0.5f;
            if (labWindowInGamut(labWindowLinearRGB(light + change.x * amount, ab + deltaAB * amount))) lower = amount;
            else upper = amount;
        }
        if (lower == 0.0f) return rgb;
        output = labWindowLinearRGB(light + change.x * lower, ab + deltaAB * lower);
    }
    return select(12.92f * output, 1.055f * pow(output, 1.0f / 2.4f) - 0.055f, output > 0.0031308f);
}

kernel void C7SelectiveHSLPhotographicLabColorWindow(texture2d<half, access::write> outputTexture [[texture(0)]],
                                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                                     constant float *adjustments [[buffer(0)]],
                                                     constant float3 &neutralShadows [[buffer(1)]],
                                                     constant float3 &neutralHighlights [[buffer(2)]],
                                                     constant float4 &hueEdges [[buffer(3)]],
                                                     constant float4 &colorAdjustment [[buffer(4)]],
                                                     constant float3 &windowTone [[buffer(5)]],
                                                     constant float4 &labHueEdges [[buffer(6)]],
                                                     constant float4 &labChromaAndHighlightEdges [[buffer(7)]],
                                                     constant float3 &labLow [[buffer(8)]],
                                                     constant float3 &labHigh [[buffer(9)]],
                                                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const half4 input = inputTexture.read(grid);
    if (input.a <= 0.0h) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float alpha = float(input.a);
    float3 styled = selectiveHSLColor(float3(input.rgb) / alpha, adjustments, true);
    styled = applySelectiveHSLColorWindow(styled, hueEdges, colorAdjustment, windowTone);
    const float3 color = finishPhotographicNeutral(styled, neutralShadows, neutralHighlights);
    // 保留上一段调色原有的半精度边界，使未命中 Lab 色窗的像素直接复用。
    const half3 original = half3(color * alpha);
    const float3 straight = float3(original) / alpha;
    const float3 adjusted = applyLabColorWindow(straight, labHueEdges, labChromaAndHighlightEdges, labLow, labHigh);
    outputTexture.write(half4(all(adjusted == straight) ? original : half3(adjusted * alpha), input.a), grid);
}

kernel void C7SelectiveHSLPhotographicLabColorWindowRefined(texture2d<half, access::write> outputTexture [[texture(0)]],
                                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                                     constant float *adjustments [[buffer(0)]],
                                                     constant float3 &neutralShadows [[buffer(1)]],
                                                     constant float3 &neutralHighlights [[buffer(2)]],
                                                     constant float4 &hueEdges [[buffer(3)]],
                                                     constant float4 &colorAdjustment [[buffer(4)]],
                                                     constant float3 &windowTone [[buffer(5)]],
                                                     constant float4 &labHueEdges [[buffer(6)]],
                                                     constant float4 &labChromaAndHighlightEdges [[buffer(7)]],
                                                     constant float3 &labLow [[buffer(8)]],
                                                     constant float3 &labHigh [[buffer(9)]],
                                                     constant float *labCorrections [[buffer(10)]],
                                                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const half4 input = inputTexture.read(grid);
    if (input.a <= 0.0h) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float alpha = float(input.a);
    float3 styled = selectiveHSLColor(float3(input.rgb) / alpha, adjustments, true);
    styled = applySelectiveHSLColorWindow(styled, hueEdges, colorAdjustment, windowTone);
    const float3 color = finishPhotographicNeutral(styled, neutralShadows, neutralHighlights);
    // 保留上一段调色原有的半精度边界，使未命中 Lab 色窗的像素直接复用。
    const half3 original = half3(color * alpha);
    const float3 straight = float3(original) / alpha;
    const float3 legacy = applyLabColorWindow(straight, labHueEdges, labChromaAndHighlightEdges, labLow, labHigh);
    const float3 adjusted = applyLabCorrections(legacy, labCorrections);
    outputTexture.write(half4(all(adjusted == straight) ? original : half3(adjusted * alpha), input.a), grid);
}

kernel void C7SelectiveHSLPhotographicHueWindow(texture2d<half, access::write> outputTexture [[texture(0)]],
                                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                                constant float4 &hueEdges [[buffer(0)]],
                                                constant float3 &chromaAndRotation [[buffer(1)]],
                                                uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    if (input.a <= 0.0h) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float alpha = float(input.a);
    const float3 straight = float3(input.rgb) / alpha;
    const float3 bounded = clamp(straight, 0.0, 1.0);
    float3 hsl = c7SelectiveRGBToHSL(bounded);
    const float hueWeight = smoothstep(hueEdges.x, hueEdges.y, hsl.x)
        * (1.0 - smoothstep(hueEdges.z, hueEdges.w, hsl.x));
    const float chroma = max(max(bounded.r, bounded.g), bounded.b) - min(min(bounded.r, bounded.g), bounded.b);
    const float chromaWeight = smoothstep(chromaAndRotation.x, chromaAndRotation.y, chroma);
    const float rotation = chromaAndRotation.z * hueWeight * chromaWeight * smoothstep(0.045, 0.16, hsl.z);
    if (rotation == 0.0) {
        outputTexture.write(input, grid);
        return;
    }
    hsl.x = fmod(hsl.x + rotation + 360.0, 360.0);
    const float3 result = c7SelectiveHSLToRGB(hsl) + straight - bounded;
    outputTexture.write(half4(half3(result * alpha), input.a), grid);
}
