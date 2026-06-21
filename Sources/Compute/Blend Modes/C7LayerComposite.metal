//
//  C7LayerComposite.metal
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

static inline half readMaskComponent(half4 value, float component) {
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

static inline half3 blendLayer(half3 background, half3 layer, float mode) {
    if (mode < 1.5) {
        return layer;
    } else if (mode < 2.5) {
        return min(background + layer, half3(1.0));
    } else if (mode < 3.5) {
        return background * layer;
    } else if (mode < 4.5) {
        return half3(1.0) - (half3(1.0) - background) * (half3(1.0) - layer);
    } else if (mode < 5.5) {
        return select(
            half3(1.0) - half3(2.0) * (half3(1.0) - background) * (half3(1.0) - layer),
            half3(2.0) * background * layer,
            background < half3(0.5)
        );
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
        return select(
            softDark,
            softLight,
            layer > half3(0.5)
        );
    } else if (mode < 13.5) {
        return select(
            half3(1.0) - half3(2.0) * (half3(1.0) - background) * (half3(1.0) - layer),
            half3(2.0) * background * layer,
            layer < half3(0.5)
        );
    } else if (mode < 14.5) {
        return background + layer - half3(2.0) * background * layer;
    }
    return layer;
}

kernel void C7LayerComposite(texture2d<half, access::write> outputTexture [[texture(0)]],
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
                             constant float *maskInvert [[buffer(12)]],
                             constant float *hasCompositingMask [[buffer(13)]],
                             constant float *compositingMaskComponent [[buffer(14)]],
                             constant float *compositingMaskInvert [[buffer(15)]],
                             constant float *cornerRadius [[buffer(16)]],
                             constant float *continuousCorner [[buffer(17)]],
                             constant float *tintR [[buffer(18)]],
                             constant float *tintG [[buffer(19)]],
                             constant float *tintB [[buffer(20)]],
                             constant float *tintA [[buffer(21)]],
                             constant float *hasTint [[buffer(22)]],
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
    if (*hasTint > 0.5) {
        const half3 tintColor = half3(*tintR, *tintG, *tintB);
        layerColor = mix(layerColor, layerColor * tintColor, half(clamp(*tintA, 0.0, 1.0)));
    }

    half coverage = half(clamp(*opacity, 0.0, 1.0));
    coverage *= layer.a;

    if (*hasMask > 0.5) {
        half maskValue = readMaskComponent(maskTexture.sample(quadSampler, outputUV), *maskComponent);
        if (*maskInvert > 0.5) {
            maskValue = half(1.0) - maskValue;
        }
        coverage *= clamp(maskValue, half(0.0), half(1.0));
    }

    if (*hasCompositingMask > 0.5) {
        half maskValue = readMaskComponent(compositingMaskTexture.sample(quadSampler, outputUV), *compositingMaskComponent);
        if (*compositingMaskInvert > 0.5) {
            maskValue = half(1.0) - maskValue;
        }
        coverage *= clamp(maskValue, half(0.0), half(1.0));
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

    const half3 blended = blendLayer(background.rgb, layerColor, *blendMode);
    const half3 rgb = mix(background.rgb, blended, coverage);
    const half alpha = max(background.a, coverage);
    outputTexture.write(half4(rgb, alpha), grid);
}
