//
//  C7ToneMapping.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ToneMapping(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float2 &sourceLuminance [[buffer(0)]],
                          constant float2 &targetLuminance [[buffer(1)]],
                          constant float2 &appearance [[buffer(2)]],
                          uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;

    const half4 input = inputTexture.read(grid);
    const float alpha = float(input.a);
    if (alpha <= 0.0f) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    const float3 source = max(float3(input.rgb) / alpha, float3(0.0f));
    const float inputNitsPerUnit = max(sourceLuminance.x, 0.0001f);
    const float sourcePeakNits = max(sourceLuminance.y, 0.0001f);
    const float targetReferenceWhiteNits = max(targetLuminance.x, 0.0001f);
    const float targetPeakNits = max(targetLuminance.y, targetReferenceWhiteNits);
    const float shoulderStrength = max(appearance.x, 0.0001f);
    const float highlightDesaturation = clamp(appearance.y, 0.0f, 1.0f);

    // HDR PQ/HLG sources use BT.2020 primaries before the output gamut conversion.
    const float luminance = dot(source, float3(0.2627f, 0.6780f, 0.0593f));
    const float luminanceNits = luminance * inputNitsPerUnit;
    const float normalizedInput = max(luminanceNits / targetReferenceWhiteNits, 0.0f);
    const float sourceHeadroom = max(sourcePeakNits / targetReferenceWhiteNits, 1.0f);
    const float targetHeadroom = max(targetPeakNits / targetReferenceWhiteNits, 1.0f);

    float mappedLuminance = normalizedInput;
    if (normalizedInput > 1.0f) {
        const float normalizedHighlight = sourceHeadroom > 1.0f
            ? clamp((normalizedInput - 1.0f) / (sourceHeadroom - 1.0f), 0.0f, 1.0f)
            : 1.0f;
        const float shoulder = log(1.0f + shoulderStrength * normalizedHighlight)
            / log(1.0f + shoulderStrength);
        mappedLuminance = 1.0f + shoulder * (targetHeadroom - 1.0f);
    }

    const float ratio = luminance > 0.000001f ? mappedLuminance / luminance : 0.0f;
    float3 mapped = source * ratio;
    const float highlightWeight = sourceHeadroom > 1.0f
        ? smoothstep(1.0f, sourceHeadroom, normalizedInput)
        : step(1.0f, normalizedInput);
    mapped = mix(mapped, float3(mappedLuminance), highlightWeight * highlightDesaturation);
    mapped = clamp(mapped, float3(0.0f), float3(targetHeadroom));

    outputTexture.write(half4(half3(mapped * alpha), input.a), grid);
}
