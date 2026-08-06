//
//  C7SceneRelight.metal
//  Harbeth
//
//  Created by Condy on 2026/7/31.
//

#include <metal_stdlib>
using namespace metal;

constant int c7SceneRelightHeaderCount = 16;
constant int c7SceneRelightLightStride = 16;
constant int c7SceneRelightMaximumLightCount = 3;

static bool c7SceneRelightFinite(float3 value) {
    return all(isfinite(value));
}

static float3 c7SceneRelightSafeNormalize(float3 value, float3 fallback) {
    const float lengthSquared = dot(value, value);
    if (!c7SceneRelightFinite(value) || !isfinite(lengthSquared) || lengthSquared <= 0.000001) {
        return fallback;
    }
    return value * rsqrt(lengthSquared);
}

static int2 c7SceneRelightClampedPixel(int2 pixel, uint width, uint height) {
    return clamp(pixel, int2(0), int2(max(int(width) - 1, 0), max(int(height) - 1, 0)));
}

struct SceneRelightScalarSample {
    float value;
    float validWeight;
};

/// 在完整画布 UV 中对低分辨率数值平面做双线性采样。
///
/// NaN/Inf 表示该 texel 无效。无效 texel 不参与加权，剩余有效权重会重新归一化；
/// 只有所有非零权重贡献都无效时，`validWeight` 才为 0。
static SceneRelightScalarSample c7SceneRelightSampleScalarPlane(
    texture2d<float, access::read> texture,
    float2 canvasUV
) {
    const uint width = texture.get_width();
    const uint height = texture.get_height();
    const float2 textureSize = float2(width, height);
    const float2 samplePosition = clamp(canvasUV, float2(0.0), float2(1.0)) * textureSize - 0.5;
    const int2 basePixel = int2(floor(samplePosition));
    const float2 fraction = clamp(samplePosition - float2(basePixel), float2(0.0), float2(1.0));
    const int2 pixel00 = c7SceneRelightClampedPixel(basePixel, width, height);
    const int2 pixel10 = c7SceneRelightClampedPixel(basePixel + int2(1, 0), width, height);
    const int2 pixel01 = c7SceneRelightClampedPixel(basePixel + int2(0, 1), width, height);
    const int2 pixel11 = c7SceneRelightClampedPixel(basePixel + int2(1, 1), width, height);
    const float4 samples = float4(
        texture.read(uint2(pixel00)).r,
        texture.read(uint2(pixel10)).r,
        texture.read(uint2(pixel01)).r,
        texture.read(uint2(pixel11)).r
    );
    const float4 weights = float4(
        (1.0 - fraction.x) * (1.0 - fraction.y),
        fraction.x * (1.0 - fraction.y),
        (1.0 - fraction.x) * fraction.y,
        fraction.x * fraction.y
    );
    const bool4 finiteMask = isfinite(samples);
    const float4 validWeights = select(float4(0.0), weights, finiteMask);
    const float validWeight = dot(validWeights, float4(1.0));
    if (validWeight <= 0.0) {
        return SceneRelightScalarSample{0.0, 0.0};
    }
    const float4 finiteSamples = select(float4(0.0), samples, finiteMask);
    return SceneRelightScalarSample{
        dot(finiteSamples, validWeights) / validWeight,
        validWeight
    };
}

kernel void C7SceneRelight(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<float, access::read> depthTexture [[texture(2)]],
                           texture2d<float, access::read> confidenceTexture [[texture(3)]],
                           constant float *parameters [[buffer(0)]],
                           constant float *mappingContext [[buffer(30)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float2 inputOrigin = float2(mappingContext[0], mappingContext[1]);
    const float2 outputOrigin = float2(mappingContext[4], mappingContext[5]);
    const float2 logicalSize = max(float2(mappingContext[6], mappingContext[7]), float2(1.0));
    const float2 globalPixel = outputOrigin + float2(grid);
    const int2 inputPixel = c7SceneRelightClampedPixel(
        int2(round(globalPixel - inputOrigin)),
        inputTexture.get_width(),
        inputTexture.get_height()
    );
    float4 source = float4(inputTexture.read(uint2(inputPixel)));
    if (!all(isfinite(source))) {
        source = select(float4(0.0), source, isfinite(source));
        outputTexture.write(half4(source), grid);
        return;
    }

    const int lightCount = int(parameters[1]);
    const bool headerIsValid = isfinite(parameters[0]) && abs(parameters[0] - 1.0) < 0.001
        && lightCount >= 0 && lightCount <= c7SceneRelightMaximumLightCount
        && all(isfinite(float4(parameters[2], parameters[3], parameters[4], parameters[5])))
        && all(isfinite(float3(parameters[6], parameters[7], parameters[8])));
    if (!headerIsValid) {
        outputTexture.write(half4(source), grid);
        return;
    }

    const float2 canvasUV = clamp((globalPixel + 0.5) / logicalSize, float2(0.0), float2(1.0));
    const float2 depthSize = float2(depthTexture.get_width(), depthTexture.get_height());
    const float2 depthTexel = 1.0 / max(depthSize, float2(1.0));
    const SceneRelightScalarSample centerDepth = c7SceneRelightSampleScalarPlane(
        depthTexture,
        canvasUV
    );
    if (centerDepth.validWeight <= 0.0) {
        outputTexture.write(half4(source), grid);
        return;
    }
    const SceneRelightScalarSample leftDepth = c7SceneRelightSampleScalarPlane(
        depthTexture,
        canvasUV - float2(depthTexel.x, 0.0)
    );
    const SceneRelightScalarSample rightDepth = c7SceneRelightSampleScalarPlane(
        depthTexture,
        canvasUV + float2(depthTexel.x, 0.0)
    );
    const SceneRelightScalarSample topDepth = c7SceneRelightSampleScalarPlane(
        depthTexture,
        canvasUV - float2(0.0, depthTexel.y)
    );
    const SceneRelightScalarSample bottomDepth = c7SceneRelightSampleScalarPlane(
        depthTexture,
        canvasUV + float2(0.0, depthTexel.y)
    );
    const float depth = centerDepth.value;
    // 洞边邻域完全无效时使用中心深度形成零侧梯度，避免整像素硬切回原图。
    const float depthLeft = leftDepth.validWeight > 0.0 ? leftDepth.value : depth;
    const float depthRight = rightDepth.validWeight > 0.0 ? rightDepth.value : depth;
    const float depthTop = topDepth.validWeight > 0.0 ? topDepth.value : depth;
    const float depthBottom = bottomDepth.validWeight > 0.0 ? bottomDepth.value : depth;

    const float normalStrength = clamp(parameters[4], 0.0, 8.0);
    const float depthScale = clamp(parameters[5], 0.0, 4.0);
    const float aspect = logicalSize.x / max(logicalSize.y, 1.0);
    const float2 canvasDepthGradient = float2(
        depthRight - depthLeft,
        depthBottom - depthTop
    ) * 0.5 * depthSize;
    // surfacePosition.x 使用 uv.x * aspect，法线必须把 d(depth)/du 转成 d(depth)/dx。
    const float2 depthGradient = clamp(
        float2(canvasDepthGradient.x / max(aspect, 0.000001), canvasDepthGradient.y),
        float2(-16.0),
        float2(16.0)
    );
    const float3 normal = c7SceneRelightSafeNormalize(
        float3(-depthGradient * normalStrength * depthScale, 1.0),
        float3(0.0, 0.0, 1.0)
    );
    const float2 uv = canvasUV;
    const float3 surfacePosition = float3(uv.x * aspect, uv.y, depth * depthScale);
    const float3 viewDirection = float3(0.0, 0.0, 1.0);
    float3 lightContribution = float3(0.0);

    for (int index = 0; index < c7SceneRelightMaximumLightCount; ++index) {
        if (index >= lightCount) {
            break;
        }
        const int base = c7SceneRelightHeaderCount + index * c7SceneRelightLightStride;
        const int kind = int(parameters[base]);
        const bool enabled = parameters[base + 1] > 0.5;
        const float3 position = float3(
            parameters[base + 2] * aspect,
            parameters[base + 3],
            parameters[base + 4]
        );
        const float3 direction = float3(
            parameters[base + 5],
            parameters[base + 6],
            parameters[base + 7]
        );
        const float3 color = float3(
            parameters[base + 8],
            parameters[base + 9],
            parameters[base + 10]
        );
        const float intensity = parameters[base + 11];
        const float radius = parameters[base + 12];
        const float softness = parameters[base + 13];
        const float coneAngle = parameters[base + 14];
        const float falloff = parameters[base + 15];
        const bool lightIsValid = kind >= 0 && kind <= 3
            && c7SceneRelightFinite(position)
            && c7SceneRelightFinite(direction)
            && c7SceneRelightFinite(color)
            && all(isfinite(float4(intensity, radius, softness, coneAngle)))
            && isfinite(falloff);
        if (!enabled || !lightIsValid || intensity <= 0.0) {
            continue;
        }

        const float3 propagationDirection = c7SceneRelightSafeNormalize(
            direction,
            float3(0.0, 0.0, -1.0)
        );
        const float3 surfaceToLight = position - surfacePosition;
        const float distanceSquared = max(dot(surfaceToLight, surfaceToLight), 0.000001);
        const float distanceToLight = sqrt(distanceSquared);
        float3 lightDirection = surfaceToLight / distanceToLight;
        float attenuation = 1.0;

        if (kind == 2) {
            lightDirection = -propagationDirection;
        } else {
            const float planarDistance = length(surfaceToLight.xy);
            const float safeRadius = max(radius, 0.001);
            const float clampedSoftness = clamp(softness, 0.0, 1.0);
            const float innerRadius = safeRadius * (1.0 - clampedSoftness);
            const float featherWidth = max(safeRadius - innerRadius, 0.0001);
            attenuation = 1.0 - smoothstep(innerRadius, innerRadius + featherWidth, planarDistance);
            attenuation *= 1.0 / (1.0 + max(falloff, 0.0) * distanceSquared);

            if (kind == 1) {
                const float outerHalfAngle = clamp(coneAngle * 0.5, 0.0087, 1.562);
                const float innerHalfAngle = max(
                    outerHalfAngle * (1.0 - clampedSoftness * 0.85),
                    0.00435
                );
                const float coneAlignment = dot(-lightDirection, propagationDirection);
                attenuation *= smoothstep(cos(outerHalfAngle), cos(innerHalfAngle), coneAlignment);
            }
        }

        float incidence = max(dot(normal, lightDirection), 0.0);
        if (kind == 3) {
            const float rim = pow(
                max(1.0 - dot(normal, viewDirection), 0.0),
                mix(5.0, 1.0, clamp(softness, 0.0, 1.0))
            );
            incidence = rim * (0.35 + 0.65 * incidence);
        }
        lightContribution += color * max(intensity, 0.0) * max(attenuation, 0.0) * incidence;
    }

    const float ambient = clamp(parameters[2], 0.0, 4.0);
    const float originalLight = clamp(parameters[3], 0.0, 1.0);
    float3 gain = mix(float3(ambient) + lightContribution, float3(1.0), originalLight);
    if (parameters[8] > 0.5) {
        const SceneRelightScalarSample confidenceSample = c7SceneRelightSampleScalarPlane(
            confidenceTexture,
            canvasUV
        );
        if (confidenceSample.validWeight <= 0.0) {
            outputTexture.write(half4(source), grid);
            return;
        }
        const float confidence = confidenceSample.value;
        const float confidenceWeight = max(clamp(confidence, 0.0, 1.0), clamp(parameters[7], 0.0, 1.0));
        gain = mix(float3(1.0), gain, confidenceWeight);
    }

    const float sourceLuminance = max(dot(source.rgb, float3(0.2126, 0.7152, 0.0722)), 0.0);
    const float rolloff = clamp(parameters[6], 0.0, 8.0);
    gain = float3(1.0) + (gain - float3(1.0)) / (1.0 + rolloff * sourceLuminance);
    const float3 outputRGB = source.rgb * gain;
    if (!c7SceneRelightFinite(gain) || !c7SceneRelightFinite(outputRGB)) {
        outputTexture.write(half4(source), grid);
        return;
    }
    outputTexture.write(half4(half3(outputRGB), half(source.a)), grid);
}
