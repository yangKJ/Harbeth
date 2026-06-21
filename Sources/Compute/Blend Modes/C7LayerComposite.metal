//
//  C7LayerComposite.metal
//  Harbeth
//
//  Created by Codex on 2026/6/21.
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
                             constant float *opacity [[buffer(4)]],
                             constant float *blendMode [[buffer(5)]],
                             constant float *hasMask [[buffer(6)]],
                             constant float *maskComponent [[buffer(7)]],
                             constant float *maskInvert [[buffer(8)]],
                             constant float *hasCompositingMask [[buffer(9)]],
                             constant float *compositingMaskComponent [[buffer(10)]],
                             constant float *compositingMaskInvert [[buffer(11)]],
                             constant float *cornerRadius [[buffer(12)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 background = backgroundTexture.read(grid);
    const float outputWidth = float(outputTexture.get_width());
    const float outputHeight = float(outputTexture.get_height());
    const float2 outputUV = float2(float(grid.x) / max(outputWidth - 1.0, 1.0),
                                   float(grid.y) / max(outputHeight - 1.0, 1.0));

    const float2 origin = float2(*frameX, *frameY);
    const float2 size = max(float2(*frameWidth, *frameHeight), float2(0.0001));
    const float2 layerUV = (outputUV - origin) / size;

    if (layerUV.x < 0.0 || layerUV.x > 1.0 || layerUV.y < 0.0 || layerUV.y > 1.0) {
        outputTexture.write(background, grid);
        return;
    }

    constexpr sampler quadSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    const half4 layer = layerTexture.sample(quadSampler, layerUV);

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
        const float2 pixelInLayer = layerUV * float2(outputWidth * size.x, outputHeight * size.y);
        const float2 layerPixelSize = float2(outputWidth * size.x, outputHeight * size.y);
        const float2 distanceToEdge = min(pixelInLayer, layerPixelSize - pixelInLayer);
        const float cornerCoverage = smoothstep(0.0, 1.0, min(distanceToEdge.x, distanceToEdge.y) / radius);
        coverage *= half(cornerCoverage);
    }

    const half3 blended = blendLayer(background.rgb, layer.rgb, *blendMode);
    const half3 rgb = mix(background.rgb, blended, coverage);
    const half alpha = max(background.a, coverage);
    outputTexture.write(half4(rgb, alpha), grid);
}
