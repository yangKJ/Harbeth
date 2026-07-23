//
//  C7ColorGrading.metal
//  Harbeth
//
//  Created by Condy on 2026/7/23.
//

#include <metal_stdlib>
using namespace metal;

static float3 c7GradeHueColor(float degrees) {
    const float hue = fmod(degrees + 360.0, 360.0) / 60.0;
    const float chroma = 1.0;
    const float secondary = chroma * (1.0 - abs(fmod(hue, 2.0) - 1.0));
    if (hue < 1.0) return float3(chroma, secondary, 0.0);
    if (hue < 2.0) return float3(secondary, chroma, 0.0);
    if (hue < 3.0) return float3(0.0, chroma, secondary);
    if (hue < 4.0) return float3(0.0, secondary, chroma);
    if (hue < 5.0) return float3(secondary, 0.0, chroma);
    return float3(chroma, 0.0, secondary);
}

static float3 c7ApplyGrade(float3 color, float3 grade, float weight) {
    const float saturation = clamp(grade.y, 0.0, 1.0);
    const float3 tint = (c7GradeHueColor(grade.x) - float3(0.5)) * saturation * 0.30 * weight;
    color += tint;
    const float luminance = clamp(grade.z, -1.0, 1.0) * 0.35 * weight;
    return luminance >= 0.0
        ? mix(color, float3(1.0), luminance)
        : color * (1.0 + luminance);
}

kernel void C7ColorGrading(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float3 *shadows [[buffer(0)]],
                           constant float3 *midtones [[buffer(1)]],
                           constant float3 *highlights [[buffer(2)]],
                           constant float3 *globalGrade [[buffer(3)]],
                           constant float *balance [[buffer(4)]],
                           constant float *blending [[buffer(5)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 source = float3(input.rgb);
    const float3 boundedSource = clamp(source, 0.0, 1.0);
    float3 color = boundedSource;
    const float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    const float pivotShift = clamp(*balance, -1.0, 1.0) * 0.18;
    const float transition = mix(0.04, 0.24, clamp(*blending, 0.0, 1.0));
    const float shadowPivot = 0.34 + pivotShift;
    const float highlightPivot = 0.66 + pivotShift;
    const float shadowWeight = 1.0 - smoothstep(shadowPivot - transition, shadowPivot + transition, luminance);
    const float highlightWeight = smoothstep(highlightPivot - transition, highlightPivot + transition, luminance);
    const float midtoneWeight = max(0.0, 1.0 - shadowWeight - highlightWeight);

    color = c7ApplyGrade(color, *shadows, shadowWeight);
    color = c7ApplyGrade(color, *midtones, midtoneWeight);
    color = c7ApplyGrade(color, *highlights, highlightWeight);
    color = c7ApplyGrade(color, *globalGrade, 1.0);
    // 保留输入的扩展范围分量，让 rgba16Float/HDR 导出不会因专业调色被强制压回 SDR。
    color += source - boundedSource;
    outputTexture.write(half4(half3(color), input.a), grid);
}
