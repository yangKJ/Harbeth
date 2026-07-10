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
                              constant float *kindPointer [[buffer(0)]],
                              constant float *value1Pointer [[buffer(1)]],
                              constant float *value2Pointer [[buffer(2)]],
                              constant float *value3Pointer [[buffer(3)]],
                              constant float *value4Pointer [[buffer(4)]],
                              constant float *value5Pointer [[buffer(5)]],
                              constant float *value6Pointer [[buffer(6)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 uv = (float2(grid) + 0.5f) / size;
    const float kind = *kindPointer;
    
    float coverage = 0.0f;
    if (kind < 0.5f) {
        const float2 startPoint = float2(*value1Pointer, *value2Pointer);
        const float2 endPoint = float2(*value3Pointer, *value4Pointer);
        const float2 delta = endPoint - startPoint;
        const float denominator = max(dot(delta, delta), 0.000001f);
        coverage = clamp(dot(uv - startPoint, delta) / denominator, 0.0f, 1.0f);
    } else {
        const float2 center = float2(*value1Pointer, *value2Pointer);
        const float startRadius = max(*value5Pointer, 0.0f);
        const float endRadius = max(*value6Pointer, startRadius + 0.000001f);
        const float distanceToCenter = distance(uv, center);
        coverage = 1.0f - smoothstep(startRadius, endRadius, distanceToCenter);
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
                                constant float *frameX [[buffer(0)]],
                                constant float *frameY [[buffer(1)]],
                                constant float *frameWidth [[buffer(2)]],
                                constant float *frameHeight [[buffer(3)]],
                                constant float *contentX [[buffer(4)]],
                                constant float *contentY [[buffer(5)]],
                                constant float *contentWidth [[buffer(6)]],
                                constant float *contentHeight [[buffer(7)]],
                                constant float *opacity [[buffer(8)]],
                                constant float *blendMode [[buffer(9)]],
                                constant float *hasMask [[buffer(10)]],
                                constant float *maskComponent [[buffer(11)]],
                                constant float *maskBlendMode [[buffer(12)]],
                                constant float *maskInvert [[buffer(13)]],
                                constant float *maskOpacity [[buffer(14)]],
                                constant float *maskFeather [[buffer(15)]],
                                constant float *hasCompositingMask [[buffer(16)]],
                                constant float *compositingMaskComponent [[buffer(17)]],
                                constant float *compositingMaskBlendMode [[buffer(18)]],
                                constant float *compositingMaskInvert [[buffer(19)]],
                                constant float *compositingMaskOpacity [[buffer(20)]],
                                constant float *compositingMaskFeather [[buffer(21)]],
                                constant float *cornerRadius [[buffer(22)]],
                                constant float *continuousCorner [[buffer(23)]],
                                constant float *tintR [[buffer(24)]],
                                constant float *tintG [[buffer(25)]],
                                constant float *tintB [[buffer(26)]],
                                constant float *tintA [[buffer(27)]],
                                constant float *hasTint [[buffer(28)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 background = backgroundTexture.read(grid);
    const float outputWidth = float(outputTexture.get_width());
    const float outputHeight = float(outputTexture.get_height());
    const float2 outputUV = float2(float(grid.x) / max(outputWidth - 1.0, 1.0),
                                   float(grid.y) / max(outputHeight - 1.0, 1.0));
    
    const float2 origin = float2(*frameX, *frameY);
    const float2 size = max(float2(*frameWidth, *frameHeight), float2(0.0001));
    const float2 regionUV = (outputUV - origin) / size;
    
    if (regionUV.x < 0.0 || regionUV.x > 1.0 || regionUV.y < 0.0 || regionUV.y > 1.0) {
        outputTexture.write(background, grid);
        return;
    }
    
    constexpr sampler quadSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    const float2 contentOrigin = float2(*contentX, *contentY);
    const float2 contentSize = max(float2(*contentWidth, *contentHeight), float2(0.0001));
    const float2 layerUV = contentOrigin + regionUV * contentSize;
    const half4 layer = layerTexture.sample(quadSampler, layerUV);
    half3 layerColor = layer.rgb;
    half layerAlpha = layer.a;
    if (*hasTint > 0.5 && *tintA > 0.0) {
        const half3 tintColor = half3(*tintR, *tintG, *tintB);
        layerColor = tintColor;
        layerAlpha *= half(clamp(*tintA, 0.0, 1.0));
    }
    
    half coverage = half(clamp(*opacity, 0.0, 1.0));
    coverage *= layerAlpha;
    half combinedMaskCoverage = half(1.0);
    bool hasCombinedMask = false;
    
    if (*hasMask > 0.5) {
        half maskValue = readInnerMaskComponent(maskTexture.sample(quadSampler, regionUV), *maskComponent);
        if (*maskInvert > 0.5) {
            maskValue = half(1.0) - maskValue;
        }
        const half feather = half(clamp(*maskFeather, 0.0, 1.0));
        if (feather > 0.0h) {
            const half low = max(0.0h, 0.5h - feather * 0.5h);
            const half high = min(1.0h, 0.5h + feather * 0.5h);
            maskValue = smoothstep(low, high, maskValue);
        }
        maskValue *= half(clamp(*maskOpacity, 0.0, 1.0));
        combinedMaskCoverage = combineInnerMaskCoverage(combinedMaskCoverage,
                                                        maskValue,
                                                        int(*maskBlendMode),
                                                        hasCombinedMask);
        hasCombinedMask = true;
    }
    
    if (*hasCompositingMask > 0.5) {
        half maskValue = readInnerMaskComponent(compositingMaskTexture.sample(quadSampler, outputUV), *compositingMaskComponent);
        if (*compositingMaskInvert > 0.5) {
            maskValue = half(1.0) - maskValue;
        }
        const half feather = half(clamp(*compositingMaskFeather, 0.0, 1.0));
        if (feather > 0.0h) {
            const half low = max(0.0h, 0.5h - feather * 0.5h);
            const half high = min(1.0h, 0.5h + feather * 0.5h);
            maskValue = smoothstep(low, high, maskValue);
        }
        maskValue *= half(clamp(*compositingMaskOpacity, 0.0, 1.0));
        combinedMaskCoverage = combineInnerMaskCoverage(combinedMaskCoverage,
                                                        maskValue,
                                                        int(*compositingMaskBlendMode),
                                                        hasCombinedMask);
        hasCombinedMask = true;
    }
    
    if (hasCombinedMask) {
        coverage *= combinedMaskCoverage;
    }
    
    const float radius = max(*cornerRadius, 0.0);
    if (radius > 0.0) {
        const float2 pixelInLayer = regionUV * float2(outputWidth * size.x, outputHeight * size.y);
        const float2 layerPixelSize = float2(outputWidth * size.x, outputHeight * size.y);
        const float2 distanceToEdge = min(pixelInLayer, layerPixelSize - pixelInLayer);
        const float softness = *continuousCorner > 0.5 ? 1.5 : 1.0;
        const float cornerCoverage = smoothstep(0.0, softness, min(distanceToEdge.x, distanceToEdge.y) / radius);
        coverage *= half(cornerCoverage);
    }
    
    const half3 blended = blendInnerLayer(background.rgb, layerColor, *blendMode);
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
                                   constant float *baseOpacityPointer [[buffer(0)]],
                                   constant float *baseInvertPointer [[buffer(1)]],
                                   constant float *baseComponentPointer [[buffer(2)]],
                                   constant float *baseFeatherPointer [[buffer(3)]],
                                   constant float *maskOpacityPointer [[buffer(4)]],
                                   constant float *maskInvertPointer [[buffer(5)]],
                                   constant float *maskComponentPointer [[buffer(6)]],
                                   constant float *maskBlendModePointer [[buffer(7)]],
                                   constant float *maskFeatherPointer [[buffer(8)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    const half4 baseColor = baseTexture.read(gid);
    const half4 maskColor = maskTexture.read(gid);
    const half baseCoverage = normalizedInnerMaskValue(baseColor,
                                                       int(*baseComponentPointer),
                                                       *baseInvertPointer > 0.5f,
                                                       half(*baseOpacityPointer),
                                                       half(*baseFeatherPointer));
    const half maskCoverage = normalizedInnerMaskValue(maskColor,
                                                       int(*maskComponentPointer),
                                                       *maskInvertPointer > 0.5f,
                                                       half(*maskOpacityPointer),
                                                       half(*maskFeatherPointer));
    const half combinedCoverage = combineInnerCoverage(baseCoverage, maskCoverage, int(*maskBlendModePointer));
    const half4 output = half4(combinedCoverage, combinedCoverage, combinedCoverage, 1.0h);
    outputTexture.write(output, gid);
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
                           constant float *kindPointer [[buffer(0)]],
                           constant float *xPointer [[buffer(1)]],
                           constant float *yPointer [[buffer(2)]],
                           constant float *widthPointer [[buffer(3)]],
                           constant float *heightPointer [[buffer(4)]],
                           constant float *featherPointer [[buffer(5)]],
                           constant float *cornerRadiusPointer [[buffer(6)]],
                           constant float *translationXPointer [[buffer(7)]],
                           constant float *translationYPointer [[buffer(8)]],
                           constant float *scaleXPointer [[buffer(9)]],
                           constant float *scaleYPointer [[buffer(10)]],
                           constant float *rotationPointer [[buffer(11)]],
                           constant float *anchorXPointer [[buffer(12)]],
                           constant float *anchorYPointer [[buffer(13)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const float2 rawUV = (float2(grid) + 0.5f) / float2(outputTexture.get_width(), outputTexture.get_height());
    const float kind = *kindPointer;
    const float2 origin = float2(*xPointer, *yPointer);
    const float2 size = max(float2(*widthPointer, *heightPointer), float2(0.000001f));
    const float feather = clamp(*featherPointer, 0.0f, 1.0f);
    const float cornerRadius = clamp(*cornerRadiusPointer, 0.0f, 0.5f);
    const float2 translation = float2(*translationXPointer, *translationYPointer);
    const float2 scaleValue = float2(*scaleXPointer, *scaleYPointer);
    const float rotation = *rotationPointer;
    const float2 anchor = float2(*anchorXPointer, *anchorYPointer);
    const float2 shifted = rawUV - anchor - translation;
    const float c = cos(-rotation);
    const float s = sin(-rotation);
    const float2 unrotated = float2(shifted.x * c - shifted.y * s, shifted.x * s + shifted.y * c);
    const float2 uv = unrotated / max(abs(scaleValue), float2(0.000001f)) + anchor;

    float coverage = 0.0f;
    if (kind < 0.5f) {
        const float2 local = (uv - origin) / size;
        const float2 edgeDistance = min(local, 1.0f - local);
        const float minEdge = min(edgeDistance.x, edgeDistance.y);
        const float featherWidth = max(feather * 0.5f, 0.000001f);
        coverage = smoothstep(0.0f, featherWidth, minEdge);
        coverage *= step(0.0f, local.x) * step(0.0f, local.y) * step(local.x, 1.0f) * step(local.y, 1.0f);
    } else if (kind < 1.5f) {
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
    const float feather = clamp(metadata[3], 0.0f, 1.0f);
    if (pointCount < 3 || subpathCount < 1) {
        outputTexture.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
        return;
    }

    const float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 uv = (float2(gid) + 0.5f) / size;
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
                minDistance = min(minDistance, innerPathDistanceToSegment(uv, a, b));
            }
        }
        if (!isinf(minDistance)) {
            coverage = inside ? 1.0f : (1.0f - smoothstep(0.0f, max(feather, 0.000001f), minDistance));
        }
    }
    outputTexture.write(half4(half3(clamp(coverage, 0.0f, 1.0f)), 1.0h), gid);
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
