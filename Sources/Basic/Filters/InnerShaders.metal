//
//  InnerShaders.metal
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void InnerGradientMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *parameters [[buffer(0)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 uv = (float2(grid) + 0.5f) / size;
    const float kind = parameters[0];

    float coverage = 0.0f;
    const float2 point1 = float2(parameters[1], parameters[2]);
    const float2 point2 = float2(parameters[3], parameters[4]);
    if (kind < 0.5f) {
        const float2 startPoint = point1;
        const float2 endPoint = point2;
        const float2 delta = endPoint - startPoint;
        const float denominator = max(dot(delta, delta), 0.000001f);
        coverage = clamp(dot(uv - startPoint, delta) / denominator, 0.0f, 1.0f);
    } else if (kind < 1.5f) {
        const float2 center = point1;
        const float startRadius = max(parameters[5], 0.0f);
        const float endRadius = max(parameters[6], startRadius + 0.000001f);
        const float distanceToCenter = distance(uv, center);
        coverage = 1.0f - smoothstep(startRadius, endRadius, distanceToCenter);
    } else if (kind < 2.5f) {
        const float twoPi = 6.28318530718f;
        float start = parameters[5];
        float span = parameters[6] - start;
        if (parameters[7] > 0.5f) {
            span = -span;
        }
        if (abs(span) < 0.000001f) span = twoPi;
        float angle = atan2(uv.y - point1.y, uv.x - point1.x);
        float delta = parameters[7] > 0.5f ? start - angle : angle - start;
        delta = fmod(delta, twoPi);
        if (delta < 0.0f) delta += twoPi;
        coverage = clamp(delta / max(abs(span), 0.000001f), 0.0f, 1.0f);
    } else if (kind < 3.5f) {
        const float radius = abs(uv.x - point1.x) + abs(uv.y - point1.y);
        coverage = 1.0f - smoothstep(max(parameters[5], 0.0f), max(parameters[6], parameters[5] + 0.000001f), radius);
    } else if (kind < 4.5f) {
        const float2 delta = point2 - point1;
        const float denominator = max(dot(delta, delta), 0.000001f);
        coverage = 1.0f - clamp(abs(dot(uv - point1, delta)) / denominator, 0.0f, 1.0f);
    } else if (kind < 5.5f) {
        const float2 segment = point2 - point1;
        const float t = clamp(dot(uv - point1, segment) / max(dot(segment, segment), 0.000001f), 0.0f, 1.0f);
        const float distanceValue = distance(uv, point1 + segment * t);
        const float halfWidth = max(parameters[5], 0.000001f);
        const float softness = clamp(parameters[6], 0.0f, 1.0f) * halfWidth;
        coverage = 1.0f - smoothstep(max(halfWidth - softness, 0.0f), halfWidth, distanceValue);
    } else if (kind < 6.5f) {
        const float distanceValue = distance(uv, point1);
        const float inner = max(parameters[5], 0.0f);
        const float peak = max(parameters[6], inner + 0.000001f);
        const float outer = max(parameters[7], peak + 0.000001f);
        coverage = smoothstep(inner, peak, distanceValue) * (1.0f - smoothstep(peak, outer, distanceValue));
    } else {
        const float2 delta = point2 - point1;
        float t = clamp(dot(uv - point1, delta) / max(dot(delta, delta), 0.000001f), 0.0f, 1.0f);
        const int curve = int(parameters[8]);
        if (curve == 1) t *= t;
        else if (curve == 2) t = 1.0f - (1.0f - t) * (1.0f - t);
        else if (curve == 3) t = t * t * (3.0f - 2.0f * t);
        else if (curve == 4) t = t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f);
        const int stopCount = clamp(int(parameters[9]), 1, 8);
        coverage = parameters[11];
        for (int index = 0; index < stopCount - 1; ++index) {
            const float location1 = parameters[10 + index * 2];
            const float value1 = parameters[11 + index * 2];
            const float location2 = parameters[12 + index * 2];
            const float value2 = parameters[13 + index * 2];
            if (t >= location1) {
                const float localT = clamp((t - location1) / max(location2 - location1, 0.000001f), 0.0f, 1.0f);
                coverage = mix(value1, value2, localT);
            }
        }
    }

    outputTexture.write(half4(half3(coverage), 1.0h), grid);
}

static inline half readInnerMaskComponent(half4 value, float component) {
    if (component < 0.5) {
        return value.a;
    } else if (component < 1.5) {
        return value.r;
    } else if (component < 2.5) {
        return value.g;
    } else if (component < 3.5) {
        return value.b;
    }
    return half(dot(float3(value.rgb), float3(0.2126, 0.7152, 0.0722)));
}

static inline half3 blendInnerLayer(half3 background, half3 layer, float mode) {
    if (mode < 1.5) {
        return layer;
    } else if (mode < 2.5) {
        return min(background + layer, half3(1.0));
    } else if (mode < 3.5) {
        return background * layer;
    } else if (mode < 4.5) {
        return half3(1.0) - (half3(1.0) - background) * (half3(1.0) - layer);
    } else if (mode < 5.5) {
        return select(half3(1.0) - half3(2.0) * (half3(1.0) - background) * (half3(1.0) - layer),
                      half3(2.0) * background * layer,
                      background < half3(0.5));
    } else if (mode < 6.5) {
        return min(background, layer);
    } else if (mode < 7.5) {
        return max(background, layer);
    } else if (mode < 8.5) {
        return abs(background - layer);
    } else if (mode < 9.5) {
        return max(background - layer, half3(0.0));
    } else if (mode < 10.5) {
        return background / max(half3(1.0) - layer, half3(0.001));
    } else if (mode < 11.5) {
        return half3(1.0) - ((half3(1.0) - background) / max(layer, half3(0.001)));
    } else if (mode < 12.5) {
        const half3 softDark = sqrt(max(background, half3(0.0))) * (half3(2.0) * layer - half3(1.0))
        + (half3(2.0) * background) * (half3(1.0) - layer);
        const half3 softLight = background - (half3(1.0) - half3(2.0) * layer) * background * (half3(1.0) - background);
        return select(softDark, softLight, layer > half3(0.5));
    } else if (mode < 13.5) {
        return select(half3(1.0) - half3(2.0) * (half3(1.0) - background) * (half3(1.0) - layer),
                      half3(2.0) * background * layer,
                      layer < half3(0.5));
    } else if (mode < 14.5) {
        return background + layer - half3(2.0) * background * layer;
    }
    return layer;
}

static inline half combineInnerMaskCoverage(half current, half maskValue, int blendMode, bool hasExistingMask) {
    const half clampedMask = clamp(maskValue, half(0.0), half(1.0));
    if (!hasExistingMask) {
        if (blendMode == 4) {
            return half(1.0) - clampedMask;
        }
        return clampedMask;
    }

    switch (blendMode) {
        case 2:
            return clamp(current + clampedMask, half(0.0), half(1.0));
        case 3:
            return clamp(current * clampedMask, half(0.0), half(1.0));
        case 4:
            return clamp(current * (half(1.0) - clampedMask), half(0.0), half(1.0));
        case 1:
        case 0:
        default:
            return clampedMask;
    }
}

kernel void InnerLayerComposite(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> backgroundTexture [[texture(1)]],
                                texture2d<half, access::sample> layerTexture [[texture(2)]],
                                texture2d<half, access::sample> maskTexture [[texture(3)]],
                                texture2d<half, access::sample> compositingMaskTexture [[texture(4)]],
                                constant float4 &normalizedFrame [[buffer(0)]],
                                constant float4 &contentRegion [[buffer(1)]],
                                constant float4 &layerOptions [[buffer(2)]],
                                constant float4 &maskOptions [[buffer(3)]],
                                constant float2 &maskCoverage [[buffer(4)]],
                                constant float4 &compositingMaskOptions [[buffer(5)]],
                                constant float2 &compositingMaskCoverage [[buffer(6)]],
                                constant float4 &tint [[buffer(7)]],
                                constant bool &hasTint [[buffer(8)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 background = backgroundTexture.read(grid);
    const float outputWidth = float(outputTexture.get_width());
    const float outputHeight = float(outputTexture.get_height());
    const float2 outputUV = float2(float(grid.x) / max(outputWidth - 1.0, 1.0),
                                   float(grid.y) / max(outputHeight - 1.0, 1.0));

    const float2 origin = normalizedFrame.xy;
    const float2 size = max(normalizedFrame.zw, float2(0.0001));
    const float2 regionUV = (outputUV - origin) / size;

    if (regionUV.x < 0.0 || regionUV.x > 1.0 || regionUV.y < 0.0 || regionUV.y > 1.0) {
        outputTexture.write(background, grid);
        return;
    }

    constexpr sampler quadSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    const float2 contentOrigin = contentRegion.xy;
    const float2 contentSize = max(contentRegion.zw, float2(0.0001));
    const float2 layerUV = contentOrigin + regionUV * contentSize;
    const half4 layer = layerTexture.sample(quadSampler, layerUV);
    half3 layerColor = layer.rgb;
    half layerAlpha = layer.a;
    if (hasTint && tint.a > 0.0) {
        layerColor = half3(tint.rgb);
        layerAlpha *= half(clamp(tint.a, 0.0, 1.0));
    }

    half coverage = half(clamp(layerOptions.x, 0.0, 1.0));
    coverage *= layerAlpha;
    half combinedMaskCoverage = half(1.0);
    bool hasCombinedMask = false;

    if (maskOptions.x > 0.5) {
        half maskValue = readInnerMaskComponent(maskTexture.sample(quadSampler, regionUV), maskOptions.y);
        if (maskOptions.w > 0.5) {
            maskValue = half(1.0) - maskValue;
        }
        const half feather = half(clamp(maskCoverage.y, 0.0, 1.0));
        if (feather > 0.0h) {
            const half low = max(0.0h, 0.5h - feather * 0.5h);
            const half high = min(1.0h, 0.5h + feather * 0.5h);
            maskValue = smoothstep(low, high, maskValue);
        }
        maskValue *= half(clamp(maskCoverage.x, 0.0, 1.0));
        combinedMaskCoverage = combineInnerMaskCoverage(combinedMaskCoverage,
                                                        maskValue,
                                                        int(maskOptions.z),
                                                        hasCombinedMask);
        hasCombinedMask = true;
    }

    if (compositingMaskOptions.x > 0.5) {
        half maskValue = readInnerMaskComponent(compositingMaskTexture.sample(quadSampler, outputUV), compositingMaskOptions.y);
        if (compositingMaskOptions.w > 0.5) {
            maskValue = half(1.0) - maskValue;
        }
        const half feather = half(clamp(compositingMaskCoverage.y, 0.0, 1.0));
        if (feather > 0.0h) {
            const half low = max(0.0h, 0.5h - feather * 0.5h);
            const half high = min(1.0h, 0.5h + feather * 0.5h);
            maskValue = smoothstep(low, high, maskValue);
        }
        maskValue *= half(clamp(compositingMaskCoverage.x, 0.0, 1.0));
        combinedMaskCoverage = combineInnerMaskCoverage(combinedMaskCoverage,
                                                        maskValue,
                                                        int(compositingMaskOptions.z),
                                                        hasCombinedMask);
        hasCombinedMask = true;
    }

    if (hasCombinedMask) {
        coverage *= combinedMaskCoverage;
    }

    const float radius = max(layerOptions.z, 0.0);
    if (radius > 0.0) {
        const float2 pixelInLayer = regionUV * float2(outputWidth * size.x, outputHeight * size.y);
        const float2 layerPixelSize = float2(outputWidth * size.x, outputHeight * size.y);
        const float2 distanceToEdge = min(pixelInLayer, layerPixelSize - pixelInLayer);
        const float softness = layerOptions.w > 0.5 ? 1.5 : 1.0;
        const float cornerCoverage = smoothstep(0.0, softness, min(distanceToEdge.x, distanceToEdge.y) / radius);
        coverage *= half(cornerCoverage);
    }

    const half3 blended = blendInnerLayer(background.rgb, layerColor, layerOptions.y);
    const half3 rgb = mix(background.rgb, blended, coverage);
    const half alpha = background.a + (1.0h - background.a) * coverage;
    outputTexture.write(half4(rgb, alpha), grid);
}

static inline half innerCoverageMaskComponentValue(half4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));
        default: return color.a;
    }
}

static inline half normalizedInnerMaskValue(half4 color,
                                            int component,
                                            bool invert,
                                            half opacity,
                                            half feather) {
    half value = innerCoverageMaskComponentValue(color, component);
    if (invert) {
        value = 1.0h - value;
    }
    if (feather > 0.0h) {
        const half low = max(0.0h, 0.5h - feather * 0.5h);
        const half high = min(1.0h, 0.5h + feather * 0.5h);
        value = smoothstep(low, high, value);
    }
    return clamp(value * opacity, 0.0h, 1.0h);
}

static inline half combineInnerCoverage(half baseCoverage, half maskCoverage, int blendMode) {
    switch (blendMode) {
        case 2:
            return clamp(baseCoverage + maskCoverage, 0.0h, 1.0h);
        case 3:
            return clamp(baseCoverage * maskCoverage, 0.0h, 1.0h);
        case 4:
            return clamp(baseCoverage * (1.0h - maskCoverage), 0.0h, 1.0h);
        case 5:
            return clamp(baseCoverage * (1.0h - maskCoverage) + maskCoverage * (1.0h - baseCoverage), 0.0h, 1.0h);
        case 1:
        case 0:
        default:
            return maskCoverage;
    }
}

kernel void InnerMaskCoverageBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> baseTexture [[texture(1)]],
                                   texture2d<half, access::read> maskTexture [[texture(2)]],
                                   constant float4 &baseMask [[buffer(0)]],
                                   constant float4 &overlayMask [[buffer(1)]],
                                   constant float &overlayFeather [[buffer(2)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 baseColor = baseTexture.read(gid);
    const half4 maskColor = maskTexture.read(gid);
    const half baseCoverage = normalizedInnerMaskValue(baseColor,
                                                       int(baseMask.z),
                                                       baseMask.y > 0.5f,
                                                       half(baseMask.x),
                                                       half(baseMask.w));
    const half maskCoverage = normalizedInnerMaskValue(maskColor,
                                                       int(overlayMask.z),
                                                       overlayMask.y > 0.5f,
                                                       half(overlayMask.x),
                                                       half(overlayFeather));
    const half combinedCoverage = combineInnerCoverage(baseCoverage, maskCoverage, int(overlayMask.w));
    const half4 output = half4(combinedCoverage, combinedCoverage, combinedCoverage, 1.0h);
    outputTexture.write(output, gid);
}

kernel void InnerMaskCoverageBlendBatch4(texture2d<half, access::write> outputTexture [[texture(0)]],
                                         texture2d<half, access::read> baseTexture [[texture(1)]],
                                         texture2d<half, access::read> mask0 [[texture(2)]],
                                         texture2d<half, access::read> mask1 [[texture(3)]],
                                         texture2d<half, access::read> mask2 [[texture(4)]],
                                         texture2d<half, access::read> mask3 [[texture(5)]],
                                         constant float4 &baseMask [[buffer(0)]],
                                         constant int &maskCount [[buffer(1)]],
                                         constant float *maskParameters0 [[buffer(2)]],
                                         constant float *maskParameters1 [[buffer(3)]],
                                         constant float *maskParameters2 [[buffer(4)]],
                                         constant float *maskParameters3 [[buffer(5)]],
                                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    half coverage = normalizedInnerMaskValue(baseTexture.read(gid), int(baseMask.z), baseMask.y > 0.5f, half(baseMask.x), half(baseMask.w));
    const int count = clamp(maskCount, 0, 4);
    if (count > 0) {
        const half value = normalizedInnerMaskValue(mask0.read(gid), int(maskParameters0[2]), maskParameters0[1] > 0.5f, half(maskParameters0[0]), half(maskParameters0[4]));
        coverage = combineInnerCoverage(coverage, value, int(maskParameters0[3]));
    }
    if (count > 1) {
        const half value = normalizedInnerMaskValue(mask1.read(gid), int(maskParameters1[2]), maskParameters1[1] > 0.5f, half(maskParameters1[0]), half(maskParameters1[4]));
        coverage = combineInnerCoverage(coverage, value, int(maskParameters1[3]));
    }
    if (count > 2) {
        const half value = normalizedInnerMaskValue(mask2.read(gid), int(maskParameters2[2]), maskParameters2[1] > 0.5f, half(maskParameters2[0]), half(maskParameters2[4]));
        coverage = combineInnerCoverage(coverage, value, int(maskParameters2[3]));
    }
    if (count > 3) {
        const half value = normalizedInnerMaskValue(mask3.read(gid), int(maskParameters3[2]), maskParameters3[1] > 0.5f, half(maskParameters3[0]), half(maskParameters3[4]));
        coverage = combineInnerCoverage(coverage, value, int(maskParameters3[3]));
    }
    outputTexture.write(half4(coverage, coverage, coverage, 1.0h), gid);
}

static inline half extractInnerMaskComponentValue(half4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));
        default: return color.a;
    }
}

kernel void InnerMaskCoverageExtract(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                     constant float *opacityPointer [[buffer(0)]],
                                     constant float *invertPointer [[buffer(1)]],
                                     constant float *componentPointer [[buffer(2)]],
                                     constant float *featherPointer [[buffer(3)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 input = inputTexture.read(gid);
    half coverage = extractInnerMaskComponentValue(input, int(*componentPointer));
    if (*invertPointer > 0.5f) {
        coverage = 1.0h - coverage;
    }
    const half feather = half(*featherPointer);
    if (feather > 0.0h) {
        const half low = max(0.0h, 0.5h - feather * 0.5h);
        const half high = min(1.0h, 0.5h + feather * 0.5h);
        coverage = smoothstep(low, high, coverage);
    }
    coverage = clamp(coverage * half(*opacityPointer), 0.0h, 1.0h);
    outputTexture.write(half4(coverage, coverage, coverage, 1.0h), gid);
}

static inline half innerMaskComponentValue(half4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));
        default: return color.a;
    }
}

kernel void InnerMaskRegionBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 texture2d<half, access::read> effectTexture [[texture(2)]],
                                 texture2d<half, access::read> maskTexture [[texture(3)]],
                                 constant float *opacityPointer [[buffer(0)]],
                                 constant float *invertPointer [[buffer(1)]],
                                 constant float *componentPointer [[buffer(2)]],
                                 constant float *blendModePointer [[buffer(3)]],
                                 constant float *featherPointer [[buffer(4)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 base = inputTexture.read(gid);
    const half4 effect = effectTexture.read(gid);
    const half4 maskColor = maskTexture.read(gid);

    half mask = innerMaskComponentValue(maskColor, int(*componentPointer));
    if (*invertPointer > 0.5f) {
        mask = 1.0h - mask;
    }
    const half feather = half(*featherPointer);
    if (feather > 0.0h) {
        const half low = max(0.0h, 0.5h - feather * 0.5h);
        const half high = min(1.0h, 0.5h + feather * 0.5h);
        mask = smoothstep(low, high, mask);
    }
    mask *= half(*opacityPointer);

    half4 output = mix(base, effect, mask);
    switch (int(*blendModePointer)) {
        case 1:
            output = base * (1.0h - mask) + effect * mask;
            break;
        case 2:
            output = base + effect * mask;
            break;
        case 3:
            output = base * mix(half4(1.0h), effect, mask);
            break;
        case 4:
            output = mix(base, max(base - effect, half4(0.0h)), mask);
            break;
        default:
            break;
    }
    outputTexture.write(output, gid);
}

kernel void InnerShapeMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant int &kind [[buffer(0)]],
                           constant float4 &frame [[buffer(1)]],
                           constant float2 &appearance [[buffer(2)]],
                           constant float2 &translation [[buffer(3)]],
                           constant float2 &scale [[buffer(4)]],
                           constant float2 &rotation [[buffer(5)]],
                           constant float2 &anchor [[buffer(6)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const float2 rawUV = (float2(grid) + 0.5f) / float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 origin = frame.xy;
    const float2 size = max(frame.zw, float2(0.000001f));
    const float feather = clamp(appearance.x, 0.0f, 1.0f);
    const float cornerRadius = clamp(appearance.y, 0.0f, 0.5f);
    const float2 scaleValue = scale;
    const float rotationRadians = rotation.x;
    const float2 shifted = rawUV - anchor - translation;
    const float rotationAspect = max(abs(rotation.y), 0.000001f);
    const float2 aspectAdjusted = float2(shifted.x * rotationAspect, shifted.y);
    const float c = cos(-rotationRadians);
    const float s = sin(-rotationRadians);
    const float2 unrotated = float2(
        aspectAdjusted.x * c - aspectAdjusted.y * s,
        aspectAdjusted.x * s + aspectAdjusted.y * c
    );
    const float2 normalizedRotation = float2(unrotated.x / rotationAspect, unrotated.y);
    const float2 uv = normalizedRotation / max(abs(scaleValue), float2(0.000001f)) + anchor;

    float coverage = 0.0f;
    if (kind == 0) {
        const float2 local = (uv - origin) / size;
        const float2 edgeDistance = min(local, 1.0f - local);
        const float minEdge = min(edgeDistance.x, edgeDistance.y);
        const float featherWidth = max(feather * 0.5f, 0.000001f);
        coverage = smoothstep(0.0f, featherWidth, minEdge);
        coverage *= step(0.0f, local.x) * step(0.0f, local.y) * step(local.x, 1.0f) * step(local.y, 1.0f);
    } else if (kind == 1) {
        const float2 center = origin + size * 0.5f;
        const float2 radius = size * 0.5f;
        const float2 normalized = (uv - center) / max(radius, float2(0.000001f));
        const float distanceValue = length(normalized);
        const float featherWidth = max(feather, 0.000001f);
        coverage = 1.0f - smoothstep(1.0f - featherWidth, 1.0f, distanceValue);
    } else {
        const float2 local = (uv - origin) / size;
        const float2 center = local - 0.5f;
        const float2 q = abs(center) - 0.5f + cornerRadius;
        const float outsideDistance = length(float2(max(q.x, 0.0f), max(q.y, 0.0f)));
        const float insideDistance = min(max(q.x, q.y), 0.0f);
        const float sdf = outsideDistance + insideDistance;
        const float featherWidth = max(feather * 0.5f, 0.000001f);
        coverage = 1.0f - smoothstep(-featherWidth, featherWidth, sdf);
    }

    outputTexture.write(half4(half3(clamp(coverage, 0.0f, 1.0f)), 1.0h), grid);
}

static inline bool innerPathEdgeCrossesRay(float2 point, float2 a, float2 b) {
    return ((a.y > point.y) != (b.y > point.y));
}

static inline float innerPathRayIntersectionX(float2 point, float2 a, float2 b) {
    const float denominator = b.y - a.y;
    return (b.x - a.x) * (point.y - a.y) / (abs(denominator) < 0.0000001f ? 0.0000001f : denominator) + a.x;
}

static inline float innerPathDistanceToSegment(float2 point, float2 a, float2 b) {
    const float2 ab = b - a;
    const float t = clamp(dot(point - a, ab) / max(dot(ab, ab), 0.0000001f), 0.0f, 1.0f);
    return distance(point, a + ab * t);
}

kernel void InnerPathMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *metadata [[buffer(0)]],
                          constant float2 *points [[buffer(1)]],
                          constant float2 *ranges [[buffer(2)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const int pointCount = int(metadata[0]);
    const int subpathCount = int(metadata[1]);
    const bool useEvenOdd = metadata[2] > 0.5f;
    const float feather = max(metadata[3], 0.0f);
    if (pointCount < 3 || subpathCount < 1) {
        outputTexture.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
        return;
    }

    const float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 uv = (float2(gid) + 0.5f) / size;
    const float shortEdge = max(min(size.x, size.y), 1.0f);
    const float2 distanceMetric = size / shortEdge;
    bool evenOddInside = false;
    int windingNumber = 0;

    for (int subpathIndex = 0; subpathIndex < subpathCount; ++subpathIndex) {
        const int start = int(ranges[subpathIndex].x);
        const int count = int(ranges[subpathIndex].y);
        if (count < 3 || start < 0 || start + count > pointCount) {
            continue;
        }

        for (int edgeIndex = 0; edgeIndex < count; ++edgeIndex) {
            const float2 a = points[start + edgeIndex];
            const float2 b = points[start + ((edgeIndex + 1) % count)];
            if (!innerPathEdgeCrossesRay(uv, a, b)) {
                continue;
            }
            const float intersectionX = innerPathRayIntersectionX(uv, a, b);
            if (uv.x >= intersectionX) {
                continue;
            }
            if (useEvenOdd) {
                evenOddInside = !evenOddInside;
            } else if (b.y > a.y) {
                windingNumber += 1;
            } else {
                windingNumber -= 1;
            }
        }
    }

    const bool inside = useEvenOdd ? evenOddInside : windingNumber != 0;
    float coverage = inside ? 1.0f : 0.0f;
    if (feather > 0.0f) {
        float minDistance = INFINITY;
        for (int subpathIndex = 0; subpathIndex < subpathCount; ++subpathIndex) {
            const int start = int(ranges[subpathIndex].x);
            const int count = int(ranges[subpathIndex].y);
            if (count < 3 || start < 0 || start + count > pointCount) {
                continue;
            }
            for (int edgeIndex = 0; edgeIndex < count; ++edgeIndex) {
                const float2 a = points[start + edgeIndex];
                const float2 b = points[start + ((edgeIndex + 1) % count)];
                minDistance = min(minDistance, innerPathDistanceToSegment(uv * distanceMetric, a * distanceMetric, b * distanceMetric));
            }
        }
        if (!isinf(minDistance)) {
            coverage = inside ? 1.0f : (1.0f - smoothstep(0.0f, max(feather, 0.000001f), minDistance));
        }
    }
    outputTexture.write(half4(half3(clamp(coverage, 0.0f, 1.0f)), 1.0h), gid);
}

kernel void InnerBrushMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *metadata [[buffer(0)]],
                           constant float4 *points [[buffer(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const int pointCount = min(max(int(metadata[0]), 0), 512);
    if (pointCount == 0) {
        outputTexture.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
        return;
    }
    const float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    const float shortEdge = max(min(size.x, size.y), 1.0f);
    const float2 metric = size / shortEdge;
    const float2 point = ((float2(gid) + 0.5f) / size) * metric;
    const float baseRadius = max(metadata[1] * 0.5f, 0.0005f);
    const float pixelRadius = 0.5f / shortEdge;
    const float hardness = clamp(metadata[2], 0.0f, 1.0f);
    float coverage = 0.0f;
    if (pointCount == 1) {
        const float radius = baseRadius * clamp(points[0].z, 0.05f, 1.0f);
        const float distanceValue = distance(point, points[0].xy * metric);
        coverage = 1.0f - smoothstep(max(radius * hardness - pixelRadius, 0.0f), radius + pixelRadius, distanceValue);
    } else {
        for (int index = 0; index < pointCount - 1; ++index) {
            const float2 a = points[index].xy * metric;
            const float2 b = points[index + 1].xy * metric;
            const float2 segment = b - a;
            const float t = clamp(dot(point - a, segment) / max(dot(segment, segment), 0.0000001f), 0.0f, 1.0f);
            const float pressure = mix(points[index].z, points[index + 1].z, t);
            const float radius = baseRadius * clamp(pressure, 0.05f, 1.0f);
            const float distanceValue = distance(point, a + segment * t);
            coverage = max(coverage, 1.0f - smoothstep(max(radius * hardness - pixelRadius, 0.0f), radius + pixelRadius, distanceValue));
        }
    }
    coverage = min(coverage * clamp(metadata[5], 0.0f, 1.0f), clamp(metadata[6], 0.0f, 1.0f));
    outputTexture.write(half4(half3(clamp(coverage, 0.0f, 1.0f)), 1.0h), gid);
}

kernel void InnerIncrementalMaskClear(texture2d<half, access::read_write> canvas [[texture(0)]],
                                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= canvas.get_width() || gid.y >= canvas.get_height()) return;
    canvas.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
}

static inline float innerIncrementalBrushStroke(constant float *metadata, constant float4 *points, uint2 gid, uint width, uint height) {
    const int pointCount = min(max(int(metadata[0]), 0), 512);
    const float2 size = float2(width, height);
    const float shortEdge = max(min(size.x, size.y), 1.0f);
    const float2 metric = size / shortEdge;
    const float2 point = ((float2(gid) + 0.5f) / size) * metric;
    const float baseRadius = max(metadata[1] * 0.5f, 0.0005f);
    const float pixelRadius = 0.5f / shortEdge;
    const float hardness = clamp(metadata[2], 0.0f, 1.0f);
    float stroke = 0.0f;
    if (pointCount == 1) {
        const float radius = baseRadius * clamp(points[0].z, 0.05f, 1.0f);
        return 1.0f - smoothstep(
            max(radius * hardness - pixelRadius, 0.0f),
            radius + pixelRadius,
            distance(point, points[0].xy * metric)
        );
    }
    for (int index = 0; index < pointCount - 1; ++index) {
        const float2 a = points[index].xy * metric;
        const float2 b = points[index + 1].xy * metric;
        const float2 segment = b - a;
        const float t = clamp(dot(point - a, segment) / max(dot(segment, segment), 0.0000001f), 0.0f, 1.0f);
        const float pressure = mix(points[index].z, points[index + 1].z, t);
        const float radius = baseRadius * clamp(pressure, 0.05f, 1.0f);
        stroke = max(
            stroke,
            1.0f - smoothstep(
                max(radius * hardness - pixelRadius, 0.0f),
                radius + pixelRadius,
                distance(point, a + segment * t)
            )
        );
    }
    return stroke;
}

static inline float innerIncrementalBrushOutput(float current, float stroke, float flow, float density, bool erase) {
    stroke = clamp(stroke * clamp(flow, 0.0f, 1.0f), 0.0f, 1.0f);
    density = clamp(density, 0.0f, 1.0f);
    if (erase) {
        const float eraseTarget = max(current * (1.0f - stroke), 1.0f - density);
        return min(current, eraseTarget);
    }
    const float paintTarget = min(1.0f - (1.0f - current) * (1.0f - stroke), density);
    return max(current, paintTarget);
}

kernel void InnerIncrementalBrushMask(texture2d<half, access::read_write> canvas [[texture(0)]],
                                      constant float *metadata [[buffer(0)]],
                                      constant float4 *points [[buffer(1)]],
                                      uint2 localID [[thread_position_in_grid]]) {
    const uint2 origin = uint2(max(metadata[6], 0.0f), max(metadata[7], 0.0f));
    const uint2 gid = origin + localID;
    if (gid.x >= canvas.get_width() || gid.y >= canvas.get_height()) return;
    const int pointCount = min(max(int(metadata[0]), 0), 512);
    if (pointCount == 0) return;
    const float current = float(canvas.read(gid).r);
    const float stroke = innerIncrementalBrushStroke(
        metadata, points, gid, canvas.get_width(), canvas.get_height()
    );
    const float output = innerIncrementalBrushOutput(
        current, stroke, metadata[3], metadata[4], metadata[5] > 0.5f
    );
    const half value = half(clamp(output, 0.0f, 1.0f));
    canvas.write(half4(value, value, value, 1.0h), gid);
}

kernel void InnerIncrementalBrushMaskFromBaseline(texture2d<half, access::read_write> canvas [[texture(0)]],
                                                  texture2d<half, access::read> baseline [[texture(1)]],
                                                  constant float *metadata [[buffer(0)]],
                                                  constant float4 *points [[buffer(1)]],
                                                  uint2 localID [[thread_position_in_grid]]) {
    const uint2 origin = uint2(max(metadata[6], 0.0f), max(metadata[7], 0.0f));
    const uint2 gid = origin + localID;
    if (gid.x >= canvas.get_width() || gid.y >= canvas.get_height()) return;
    const int pointCount = min(max(int(metadata[0]), 0), 512);
    if (pointCount == 0) return;
    const bool erase = metadata[5] > 0.5f;
    const float baselineValue = float(baseline.read(gid).r);
    const float stroke = innerIncrementalBrushStroke(
        metadata, points, gid, canvas.get_width(), canvas.get_height()
    );
    const float candidate = innerIncrementalBrushOutput(
        baselineValue, stroke, metadata[3], metadata[4], erase
    );
    const float current = float(canvas.read(gid).r);
    const float output = erase ? min(current, candidate) : max(current, candidate);
    const half value = half(clamp(output, 0.0f, 1.0f));
    canvas.write(half4(value, value, value, 1.0h), gid);
}

static inline int innerMaskMirrorCoordinate(int value, int size) {
    if (size <= 1) return 0;
    const int period = 2 * size - 2;
    int mirrored = value % period;
    if (mirrored < 0) mirrored += period;
    return mirrored < size ? mirrored : period - mirrored;
}

static inline float innerMaskReadCoverage(texture2d<half, access::read> texture,
                                          int2 coordinate,
                                          int edgeMode) {
    const int width = int(texture.get_width());
    const int height = int(texture.get_height());
    if (edgeMode == 0 && (coordinate.x < 0 || coordinate.y < 0 || coordinate.x >= width || coordinate.y >= height)) {
        return 0.0f;
    }
    if (edgeMode == 2) {
        coordinate = int2(innerMaskMirrorCoordinate(coordinate.x, width), innerMaskMirrorCoordinate(coordinate.y, height));
    } else {
        coordinate = clamp(coordinate, int2(0), int2(max(width - 1, 0), max(height - 1, 0)));
    }
    return float(texture.read(uint2(coordinate)).r);
}

kernel void InnerMaskCoverageResample(texture2d<half, access::write> outputTexture [[texture(0)]],
                                      texture2d<half, access::read> inputTexture [[texture(1)]],
                                      constant float *filterPointer [[buffer(0)]],
                                      constant float *edgeModePointer [[buffer(1)]],
                                      constant float *thresholdPointer [[buffer(2)]],
                                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const int filterMode = int(*filterPointer);
    const int edgeMode = int(*edgeModePointer);
    const float2 sourceSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    float coverage = 0.0f;

    if (filterMode == 0) {
        const float2 source = (float2(gid) + 0.5f) * sourceSize / outputSize - 0.5f;
        coverage = innerMaskReadCoverage(inputTexture, int2(round(source)), edgeMode);
    } else if (filterMode == 2 && (sourceSize.x > outputSize.x || sourceSize.y > outputSize.y)) {
        const float2 lower = float2(gid) * sourceSize / outputSize;
        const float2 upper = float2(gid + 1u) * sourceSize / outputSize;
        const int2 first = int2(floor(lower));
        const int2 last = int2(ceil(upper));
        float weightSum = 0.0f;
        for (int y = first.y; y < last.y; ++y) {
            const float wy = max(min(upper.y, float(y + 1)) - max(lower.y, float(y)), 0.0f);
            for (int x = first.x; x < last.x; ++x) {
                const float wx = max(min(upper.x, float(x + 1)) - max(lower.x, float(x)), 0.0f);
                const float weight = wx * wy;
                coverage += innerMaskReadCoverage(inputTexture, int2(x, y), edgeMode) * weight;
                weightSum += weight;
            }
        }
        coverage /= max(weightSum, 0.000001f);
    } else {
        const float2 source = (float2(gid) + 0.5f) * sourceSize / outputSize - 0.5f;
        const int2 base = int2(floor(source));
        const float2 fraction = source - float2(base);
        const float top = mix(
            innerMaskReadCoverage(inputTexture, base, edgeMode),
            innerMaskReadCoverage(inputTexture, base + int2(1, 0), edgeMode),
            fraction.x
        );
        const float bottom = mix(
            innerMaskReadCoverage(inputTexture, base + int2(0, 1), edgeMode),
            innerMaskReadCoverage(inputTexture, base + int2(1, 1), edgeMode),
            fraction.x
        );
        coverage = mix(top, bottom, fraction.y);
    }

    if (*thresholdPointer >= 0.0f) coverage = coverage >= *thresholdPointer ? 1.0f : 0.0f;
    const half value = half(clamp(coverage, 0.0f, 1.0f));
    outputTexture.write(half4(value, value, value, 1.0h), gid);
}

kernel void InnerMaskSignedDistanceCombine(texture2d<half, access::write> outputTexture [[texture(0)]],
                                           texture2d<half, access::read> distanceToInside [[texture(1)]],
                                           texture2d<half, access::read> distanceToOutside [[texture(2)]],
                                           constant float *maxDistancePointer [[buffer(0)]],
                                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const float maxDistance = max(*maxDistancePointer, 1.0f);
    const float signedDistance = clamp(
        float(distanceToInside.read(gid).r) - float(distanceToOutside.read(gid).r),
        -maxDistance,
        maxDistance
    );
    const half normalized = half(signedDistance / (2.0f * maxDistance) + 0.5f);
    outputTexture.write(half4(normalized, normalized, normalized, 1.0h), gid);
}

kernel void InnerMaskSignedDistanceCoverage(texture2d<half, access::write> outputTexture [[texture(0)]],
                                            texture2d<half, access::read> inputTexture [[texture(1)]],
                                            constant float *shiftPointer [[buffer(0)]],
                                            constant float *innerPointer [[buffer(1)]],
                                            constant float *outerPointer [[buffer(2)]],
                                            constant float *maxDistancePointer [[buffer(3)]],
                                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const float maxDistance = max(*maxDistancePointer, 1.0f);
    const float signedDistance = (float(inputTexture.read(gid).r) - 0.5f) * 2.0f * maxDistance - *shiftPointer;
    const float inner = max(*innerPointer, 0.0f);
    const float outer = max(*outerPointer, 0.0f);
    float coverage;
    if (inner + outer < 0.000001f) {
        coverage = signedDistance <= 0.0f ? 1.0f : 0.0f;
    } else {
        coverage = 1.0f - smoothstep(-inner, max(outer, -inner + 0.000001f), signedDistance);
    }
    const half value = half(clamp(coverage, 0.0f, 1.0f));
    outputTexture.write(half4(value, value, value, 1.0h), gid);
}

kernel void InnerMaskForegroundColorDecontamination(texture2d<half, access::write> outputTexture [[texture(0)]],
                                                     texture2d<half, access::read> sourceTexture [[texture(1)]],
                                                     texture2d<half, access::read> coverageTexture [[texture(2)]],
                                                     constant float *radiusPointer [[buffer(0)]],
                                                     constant float *strengthPointer [[buffer(1)]],
                                                     constant float *opaqueThresholdPointer [[buffer(2)]],
                                                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const half4 source = sourceTexture.read(gid);
    const float coverage = float(coverageTexture.read(gid).r);
    if (coverage <= 0.0f || coverage >= *opaqueThresholdPointer || *strengthPointer <= 0.0f) {
        outputTexture.write(source, gid);
        return;
    }
    const int radius = min(max(int(*radiusPointer), 1), 32);
    float nearestDistance = INFINITY;
    half3 replacement = source.rgb;
    for (int y = -radius; y <= radius; ++y) {
        for (int x = -radius; x <= radius; ++x) {
            const int2 location = int2(gid) + int2(x, y);
            if (location.x < 0 || location.y < 0 ||
                location.x >= int(sourceTexture.get_width()) || location.y >= int(sourceTexture.get_height())) continue;
            if (float(coverageTexture.read(uint2(location)).r) < *opaqueThresholdPointer) continue;
            const float distanceSquared = float(x * x + y * y);
            if (distanceSquared < nearestDistance) {
                nearestDistance = distanceSquared;
                replacement = sourceTexture.read(uint2(location)).rgb;
            }
        }
    }
    const half amount = half(clamp((1.0f - coverage) * *strengthPointer, 0.0f, 1.0f));
    outputTexture.write(half4(mix(source.rgb, replacement, amount), source.a), gid);
}

static inline float innerMaskAuxiliaryComponent(half4 value, int component) {
    switch (component) {
        case 0: return float(value.r);
        case 1: return float(value.g);
        case 2: return float(value.b);
        case 3: return float(value.a);
        default: return float(value.r);
    }
}

kernel void InnerMaskAuxiliaryRange(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> auxiliaryTexture [[texture(1)]],
                                    texture2d<half, access::read> confidenceTexture [[texture(2)]],
                                    constant int &component [[buffer(0)]],
                                    constant float3 &range [[buffer(1)]],
                                    constant float2 &flags [[buffer(2)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const float value = innerMaskAuxiliaryComponent(auxiliaryTexture.read(gid), component);
    const float low = min(range.x, range.y);
    const float high = max(range.x, range.y);
    const float softness = max(range.z, 0.000001f);
    float coverage = isfinite(value)
        ? smoothstep(low - softness, low + softness, value) * (1.0f - smoothstep(high - softness, high + softness, value))
        : 0.0f;
    if (flags.x > 0.5f) coverage = 1.0f - coverage;
    if (flags.y > 0.5f) coverage *= float(confidenceTexture.read(gid).r);
    const half output = half(clamp(coverage, 0.0f, 1.0f));
    outputTexture.write(half4(output, output, output, 1.0h), gid);
}

kernel void InnerMaskFlowWarp(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> maskTexture [[texture(1)]],
                              texture2d<half, access::read> flowTexture [[texture(2)]],
                              texture2d<half, access::read> confidenceTexture [[texture(3)]],
                              constant float *scalePointer [[buffer(0)]],
                              constant float *normalizedPointer [[buffer(1)]],
                              constant float *usesConfidencePointer [[buffer(2)]],
                              constant float *edgeModePointer [[buffer(3)]],
                              uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const float2 size = float2(maskTexture.get_width(), maskTexture.get_height());
    float2 displacement = float2(flowTexture.read(gid).rg) * *scalePointer;
    if (*normalizedPointer > 0.5f) displacement *= size;
    const float2 source = float2(gid) + displacement;
    const int2 base = int2(floor(source));
    const float2 fraction = source - float2(base);
    const int edgeMode = int(*edgeModePointer);
    const float top = mix(
        innerMaskReadCoverage(maskTexture, base, edgeMode),
        innerMaskReadCoverage(maskTexture, base + int2(1, 0), edgeMode),
        fraction.x
    );
    const float bottom = mix(
        innerMaskReadCoverage(maskTexture, base + int2(0, 1), edgeMode),
        innerMaskReadCoverage(maskTexture, base + int2(1, 1), edgeMode),
        fraction.x
    );
    float coverage = mix(top, bottom, fraction.y);
    if (*usesConfidencePointer > 0.5f) coverage *= float(confidenceTexture.read(gid).r);
    const half output = half(clamp(coverage, 0.0f, 1.0f));
    outputTexture.write(half4(output, output, output, 1.0h), gid);
}

static inline float3 innerRGBToHSV(float3 color) {
    float4 K = float4(0.0f, -1.0f / 3.0f, 2.0f / 3.0f, -1.0f);
    float4 p = mix(float4(color.bg, K.wz), float4(color.gb, K.xy), step(color.b, color.g));
    float4 q = mix(float4(p.xyw, color.r), float4(color.r, p.yzx), step(p.x, color.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10f;
    return float3(abs(q.z + (q.w - q.y) / (6.0f * d + e)), d / (q.x + e), q.x);
}

static inline float innerRangeBand(float value, float lower, float upper, float softness) {
    const float low = min(lower, upper);
    const float high = max(lower, upper);
    const float feather = max(softness, 0.000001f);
    return smoothstep(low - feather, low + feather, value) * (1.0f - smoothstep(high - feather, high + feather, value));
}

kernel void InnerRangeMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *parameters [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const float3 rgb = float3(inputTexture.read(gid).rgb);
    const int kind = int(parameters[0]);
    float coverage = 0.0f;
    if (kind == 0) {
        const float luma = dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
        coverage = innerRangeBand(luma, parameters[1], parameters[2], parameters[3]);
    } else if (kind == 1) {
        const float luma = dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
        coverage = smoothstep(parameters[1] - parameters[3], parameters[1] + parameters[3], luma);
    } else if (kind == 2) {
        const float luma = dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
        coverage = 1.0f - smoothstep(parameters[1] - parameters[3], parameters[1] + parameters[3], luma);
    } else if (kind == 3) {
        const float hue = innerRGBToHSV(rgb).x;
        const float delta = min(abs(hue - parameters[1]), 1.0f - abs(hue - parameters[1]));
        coverage = 1.0f - smoothstep(max(parameters[2] - parameters[3], 0.0f), parameters[2] + parameters[3], delta);
    } else if (kind == 4) {
        coverage = innerRangeBand(innerRGBToHSV(rgb).y, parameters[1], parameters[2], parameters[3]);
    } else {
        const float distanceValue = distance(rgb, float3(parameters[1], parameters[2], parameters[3])) / 1.7320508f;
        coverage = 1.0f - smoothstep(max(parameters[4] - parameters[5], 0.0f), parameters[4] + parameters[5], distanceValue);
    }
    outputTexture.write(half4(half3(clamp(coverage, 0.0f, 1.0f)), 1.0h), gid);
}

kernel void InnerMaskPointThreshold(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> inputTexture [[texture(1)]],
                                    constant float *threshold [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const half value = inputTexture.read(gid).r >= half(*threshold) ? 1.0h : 0.0h;
    outputTexture.write(half4(value, value, value, 1.0h), gid);
}

kernel void InnerMaskEdgeCleanup(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 constant float *blackPoint [[buffer(0)]],
                                 constant float *whitePoint [[buffer(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;
    const float low = min(*blackPoint, *whitePoint);
    const float high = max(*whitePoint, low + 0.000001f);
    const half value = half(smoothstep(low, high, float(inputTexture.read(gid).r)));
    outputTexture.write(half4(value, value, value, 1.0h), gid);
}

kernel void MaskAnalyzeCoverageBlocks(texture2d<half, access::read> inputTexture [[texture(0)]],
                                      device uint *partials [[buffer(0)]],
                                      constant uint *parameters [[buffer(1)]],
                                      uint2 blockIndex [[thread_position_in_grid]]) {
    const uint blockSize = parameters[0];
    const uint blockCountX = parameters[1];
    const uint width = parameters[2];
    const uint height = parameters[3];
    const float threshold = as_type<float>(parameters[4]);
    const uint outputIndex = (blockIndex.y * blockCountX + blockIndex.x) * 9u;
    const uint2 origin = blockIndex * blockSize;
    uint activeCount = 0u;
    uint minX = width;
    uint minY = height;
    uint maxX = 0u;
    uint maxY = 0u;
    uint sumX = 0u;
    uint sumY = 0u;
    float coverageSum = 0.0f;
    uint edgeCount = 0u;
    for (uint y = origin.y; y < min(origin.y + blockSize, height); ++y) {
        for (uint x = origin.x; x < min(origin.x + blockSize, width); ++x) {
            const float coverage = float(inputTexture.read(uint2(x, y)).r);
            coverageSum += coverage;
            if (coverage < threshold) continue;
            activeCount += 1u;
            minX = min(minX, x); minY = min(minY, y);
            maxX = max(maxX, x); maxY = max(maxY, y);
            sumX += x; sumY += y;
            bool edge = false;
            if (x + 1u < width) edge = edge || (float(inputTexture.read(uint2(x + 1u, y)).r) < threshold);
            if (y + 1u < height) edge = edge || (float(inputTexture.read(uint2(x, y + 1u)).r) < threshold);
            if (x > 0u) edge = edge || (float(inputTexture.read(uint2(x - 1u, y)).r) < threshold);
            if (y > 0u) edge = edge || (float(inputTexture.read(uint2(x, y - 1u)).r) < threshold);
            if (edge) edgeCount += 1u;
        }
    }
    partials[outputIndex] = activeCount;
    partials[outputIndex + 1u] = minX;
    partials[outputIndex + 2u] = minY;
    partials[outputIndex + 3u] = maxX;
    partials[outputIndex + 4u] = maxY;
    partials[outputIndex + 5u] = sumX;
    partials[outputIndex + 6u] = sumY;
    partials[outputIndex + 7u] = as_type<uint>(coverageSum);
    partials[outputIndex + 8u] = edgeCount;
}

static inline uint2 InnerYCbCrScaleCoordinate(uint2 outputCoordinate,
                                              texture2d<half, access::read> planeTexture,
                                              texture2d<half, access::write> outputTexture) {
    uint planeWidth = max(planeTexture.get_width(), 1u);
    uint planeHeight = max(planeTexture.get_height(), 1u);
    uint outputWidth = max(outputTexture.get_width(), 1u);
    uint outputHeight = max(outputTexture.get_height(), 1u);
    return uint2(min((outputCoordinate.x * planeWidth) / outputWidth, planeWidth - 1),
                 min((outputCoordinate.y * planeHeight) / outputHeight, planeHeight - 1));
}

static inline half4 InnerYCbCrConvertToRGBA(float3x3 conversionMatrix,
                                            float3 conversionOffset,
                                            half y,
                                            half u,
                                            half v) {
    float3 yuv = float3(float(y), float(u), float(v)) + conversionOffset;
    float3 rgb = conversionMatrix * yuv;
    rgb = clamp(rgb, float3(0.0f), float3(1.0f));
    return half4(half3(rgb), 1.0h);
}

kernel void InnerYCbCrBiPlanarToRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> lumaTexture [[texture(1)]],
                                     texture2d<half, access::read> chromaTexture [[texture(2)]],
                                     constant float3x3 &conversionMatrix [[buffer(0)]],
                                     constant float3 &conversionOffset [[buffer(1)]],
                                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    uint2 lumaCoordinate = InnerYCbCrScaleCoordinate(grid, lumaTexture, outputTexture);
    uint2 chromaCoordinate = InnerYCbCrScaleCoordinate(grid, chromaTexture, outputTexture);
    half y = lumaTexture.read(lumaCoordinate).r;
    half2 uv = chromaTexture.read(chromaCoordinate).rg;
    outputTexture.write(InnerYCbCrConvertToRGBA(conversionMatrix, conversionOffset, y, uv.x, uv.y), grid);
}

kernel void InnerYCbCrTriPlanarToRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                                      texture2d<half, access::read> lumaTexture [[texture(1)]],
                                      texture2d<half, access::read> chromaUTexture [[texture(2)]],
                                      texture2d<half, access::read> chromaVTexture [[texture(3)]],
                                      constant float3x3 &conversionMatrix [[buffer(0)]],
                                      constant float3 &conversionOffset [[buffer(1)]],
                                      uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    uint2 lumaCoordinate = InnerYCbCrScaleCoordinate(grid, lumaTexture, outputTexture);
    uint2 uCoordinate = InnerYCbCrScaleCoordinate(grid, chromaUTexture, outputTexture);
    uint2 vCoordinate = InnerYCbCrScaleCoordinate(grid, chromaVTexture, outputTexture);
    half y = lumaTexture.read(lumaCoordinate).r;
    half u = chromaUTexture.read(uCoordinate).r;
    half v = chromaVTexture.read(vCoordinate).r;
    outputTexture.write(InnerYCbCrConvertToRGBA(conversionMatrix, conversionOffset, y, u, v), grid);
}

static inline half4 safe_read(texture2d<half, access::read> texture, uint2 gid) {
    uint x = min(gid.x, texture.get_width() - 1);
    uint y = min(gid.y, texture.get_height() - 1);
    return texture.read(uint2(x, y));
}

kernel void InnerDissolveTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> fromTexture [[texture(1)]],
                                    texture2d<half, access::read> toTexture [[texture(2)]],
                                    constant float *progressPointer [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const half progress = half(clamp(*progressPointer, 0.0f, 1.0f));
    const half4 from = safe_read(fromTexture, gid);
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, progress), gid);
}

kernel void InnerDirectionalWipeTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                           texture2d<half, access::read> fromTexture [[texture(1)]],
                                           texture2d<half, access::read> toTexture [[texture(2)]],
                                           constant float *progressPointer [[buffer(0)]],
                                           constant float *anglePointer [[buffer(1)]],
                                           constant float *softnessPointer [[buffer(2)]],
                                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const float progressValue = clamp(*progressPointer, 0.0f, 1.0f);
    const half2 uv = half2(float(gid.x) / max(float(outputTexture.get_width() - 1), 1.0f),
                           float(gid.y) / max(float(outputTexture.get_height() - 1), 1.0f));
    const half2 direction = normalize(half2(cos(*anglePointer), sin(*anglePointer)));
    const half projection = dot(uv - 0.5h, direction);
    const half softness = half(max(*softnessPointer, 0.0001f));
    const half progress = half(progressValue);
    const half halfRange = (abs(direction.x) + abs(direction.y)) * 0.5h;
    const half boundary = mix(halfRange + softness, -halfRange - softness, progress);
    const half mixFactor = smoothstep(boundary - softness, boundary + softness, projection);
    const half4 from = safe_read(fromTexture, gid);
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, mixFactor), gid);
}

kernel void InnerLumaWipeTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> fromTexture [[texture(1)]],
                                    texture2d<half, access::read> toTexture [[texture(2)]],
                                    texture2d<half, access::read> lumaTexture [[texture(3)]],
                                    constant float *progressPointer [[buffer(0)]],
                                    constant float *softnessPointer [[buffer(1)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const float progressValue = clamp(*progressPointer, 0.0f, 1.0f);
    const half4 lumaSample = safe_read(lumaTexture, gid);
    const half luma = dot(lumaSample.rgb, half3(0.299h, 0.587h, 0.114h));
    const half softness = half(max(*softnessPointer, 0.0001f));
    const half progress = half(progressValue);
    const half boundary = mix(1.0h + softness, -softness, progress);
    const half mixFactor = smoothstep(boundary - softness, boundary + softness, luma);
    const half4 from = safe_read(fromTexture, gid);
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, mixFactor), gid);
}

kernel void InnerDisplacementTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                        texture2d<half, access::read> fromTexture [[texture(1)]],
                                        texture2d<half, access::read> toTexture [[texture(2)]],
                                        texture2d<half, access::read> displacementTexture [[texture(3)]],
                                        constant float *progressPointer [[buffer(0)]],
                                        constant float *scalePointer [[buffer(1)]],
                                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const float progressValue = clamp(*progressPointer, 0.0f, 1.0f);
    if (progressValue <= 0.0f) {
        outputTexture.write(safe_read(fromTexture, gid), gid);
        return;
    }
    if (progressValue >= 1.0f) {
        outputTexture.write(safe_read(toTexture, gid), gid);
        return;
    }
    const half4 displacementSample = safe_read(displacementTexture, gid);
    const half progress = half(progressValue);
    const half2 offset = (displacementSample.rg - 0.5h) * half(*scalePointer) * half(1.0f - progressValue) * half2(outputTexture.get_width(), outputTexture.get_height());
    const int2 displaced = int2(clamp(int(gid.x) + int(offset.x), 0, int(outputTexture.get_width() - 1)),
                                clamp(int(gid.y) + int(offset.y), 0, int(outputTexture.get_height() - 1)));
    const half4 from = fromTexture.read(uint2(displaced));
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, progress), gid);
}

kernel void MaskDistanceField(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float &maxDistance [[buffer(0)]],
                              constant float &threshold [[buffer(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    const float safeDistance = max(maxDistance, 1.0f);
    const int radius = int(ceil(safeDistance));
    const bool inside = inputTexture.read(gid).r >= half(threshold);
    float best = safeDistance;
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            const int2 position = int2(gid) + int2(x, y);
            if (position.x < 0 || position.y < 0 || position.x >= int(width) || position.y >= int(height)) {
                continue;
            }
            const bool neighborInside = inputTexture.read(uint2(position)).r >= half(threshold);
            if (neighborInside == inside) {
                continue;
            }
            const float candidate = length(float2(x, y));
            best = min(best, candidate);
        }
    }
    const half normalized = half(clamp(best / safeDistance, 0.0f, 1.0f));
    outputTexture.write(half4(normalized, normalized, normalized, 1.0h), gid);
}
