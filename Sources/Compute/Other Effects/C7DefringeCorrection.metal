//
//  C7DefringeCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

static float luminance(float3 rgb) {
    return dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
}

static float3 rgbToHslDefringe(float3 rgb) {
    float maxVal = max(max(rgb.r, rgb.g), rgb.b);
    float minVal = min(min(rgb.r, rgb.g), rgb.b);
    float delta = maxVal - minVal;

    float hue = 0.0f;
    float lightness = (maxVal + minVal) * 0.5f;
    float saturation = 0.0f;

    if (delta > 0.000001f) {
        saturation = delta / max(0.000001f, (1.0f - fabs(2.0f * lightness - 1.0f)));

        if (maxVal == rgb.r) {
            hue = 60.0f * fmod(((rgb.g - rgb.b) / delta), 6.0f);
        } else if (maxVal == rgb.g) {
            hue = 60.0f * (((rgb.b - rgb.r) / delta) + 2.0f);
        } else {
            hue = 60.0f * (((rgb.r - rgb.g) / delta) + 4.0f);
        }

        if (hue < 0.0f) {
            hue += 360.0f;
        }
    }

    return float3(hue, saturation, lightness);
}

static float angularDistance(float a, float b) {
    float distance = fabs(a - b);
    return min(distance, 360.0f - distance);
}

static bool isHueInsideRange(float hue, float start, float end) {
    if (start <= end) {
        return hue >= start && hue <= end;
    }
    return hue >= start || hue <= end;
}

static float hueRangeCoverage(float hue, float start, float end, float softness) {
    if (isHueInsideRange(hue, start, end)) {
        return 1.0f;
    }

    float distance = min(angularDistance(hue, start), angularDistance(hue, end));
    return 1.0f - smoothstep(0.0f, softness, distance);
}

static float readNeighborLuma(texture2d<half, access::read> texture, int2 coordinate) {
    int2 clamped = int2(
        clamp(coordinate.x, 0, int(texture.get_width()) - 1),
        clamp(coordinate.y, 0, int(texture.get_height()) - 1)
    );
    return luminance(float3(texture.read(uint2(clamped)).rgb));
}

kernel void C7DefringeCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 constant float *purpleAmount [[buffer(0)]],
                                 constant float *purpleHueStart [[buffer(1)]],
                                 constant float *purpleHueEnd [[buffer(2)]],
                                 constant float *greenAmount [[buffer(3)]],
                                 constant float *greenHueStart [[buffer(4)]],
                                 constant float *greenHueEnd [[buffer(5)]],
                                 constant float *edgeThreshold [[buffer(6)]],
                                 constant float *saturationThreshold [[buffer(7)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    half4 inputColor = inputTexture.read(grid);
    float3 rgb = float3(inputColor.rgb);
    float3 hsl = rgbToHslDefringe(rgb);

    int2 coordinate = int2(grid);
    float centerLuma = luminance(rgb);
    float contrast = 0.0f;
    contrast = max(contrast, fabs(centerLuma - readNeighborLuma(inputTexture, coordinate + int2(-1, 0))));
    contrast = max(contrast, fabs(centerLuma - readNeighborLuma(inputTexture, coordinate + int2(1, 0))));
    contrast = max(contrast, fabs(centerLuma - readNeighborLuma(inputTexture, coordinate + int2(0, -1))));
    contrast = max(contrast, fabs(centerLuma - readNeighborLuma(inputTexture, coordinate + int2(0, 1))));

    float edgeFactor = smoothstep(*edgeThreshold, max(*edgeThreshold * 3.0f, *edgeThreshold + 0.0001f), contrast);
    float saturationFactor = smoothstep(*saturationThreshold, 1.0f, hsl.y);

    float purpleCoverage = hueRangeCoverage(hsl.x, *purpleHueStart, *purpleHueEnd, 10.0f);
    float greenCoverage = hueRangeCoverage(hsl.x, *greenHueStart, *greenHueEnd, 10.0f);

    float3 corrected = rgb;
    float purpleStrength = clamp(*purpleAmount, 0.0f, 1.0f) * purpleCoverage * edgeFactor * saturationFactor;
    if (purpleStrength > 0.0f) {
        float purpleNeutral = max(rgb.g, centerLuma);
        corrected.r = mix(corrected.r, purpleNeutral, purpleStrength);
        corrected.b = mix(corrected.b, purpleNeutral, purpleStrength);
    }

    float greenStrength = clamp(*greenAmount, 0.0f, 1.0f) * greenCoverage * edgeFactor * saturationFactor;
    if (greenStrength > 0.0f) {
        float greenNeutral = max((rgb.r + rgb.b) * 0.5f, centerLuma);
        corrected.g = mix(corrected.g, greenNeutral, greenStrength);
    }

    outputTexture.write(half4(half3(clamp(corrected, 0.0f, 1.0f)), inputColor.a), grid);
}
