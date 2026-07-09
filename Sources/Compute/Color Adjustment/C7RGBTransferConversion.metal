//
//  C7RGBTransferConversion.metal
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

static inline float harbethSRGBToLinearComponent(float value) {
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}

static inline float harbethLinearToSRGBComponent(float value) {
    return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}

static inline float3 harbethSRGBToLinear(float3 color) {
    return float3(
        harbethSRGBToLinearComponent(color.r),
        harbethSRGBToLinearComponent(color.g),
        harbethSRGBToLinearComponent(color.b)
    );
}

static inline float3 harbethLinearToSRGB(float3 color) {
    return float3(
        harbethLinearToSRGBComponent(color.r),
        harbethLinearToSRGBComponent(color.g),
        harbethLinearToSRGBComponent(color.b)
    );
}

static inline float harbethPQToLinearComponent(float value) {
    const float c1 = 0.8359375f;
    const float c2 = 18.8515625f;
    const float c3 = 18.6875f;
    const float m1 = 0.1593017578125f;
    const float m2 = 78.84375f;
    const float e = pow(max(value, 0.0f), 1.0f / m2);
    return pow(max((e - c1) / (c2 - c3 * e), 0.0f), 1.0f / m1);
}

static inline float harbethLinearToPQComponent(float value) {
    const float c1 = 0.8359375f;
    const float c2 = 18.8515625f;
    const float c3 = 18.6875f;
    const float m1 = 0.1593017578125f;
    const float m2 = 78.84375f;
    const float l = max(value, 0.0f);
    return pow((c1 + c2 * pow(l, m1)) / (1.0f + c3 * pow(l, m1)), m2);
}

static inline float harbethHLGToLinearComponent(float value) {
    const float a = 0.17883277f;
    const float b = 0.28466892f;
    const float c = 0.55991073f;
    const float v = max(value, 0.0f);
    return v <= 0.5f ? (v * v) / 3.0f : (exp((v - c) / a) + b) / 12.0f;
}

static inline float harbethLinearToHLGComponent(float value) {
    const float a = 0.17883277f;
    const float b = 0.28466892f;
    const float c = 0.55991073f;
    const float l = max(value, 0.0f);
    return l <= (1.0f / 12.0f) ? sqrt(3.0f * l) : a * log(12.0f * l - b) + c;
}

static inline float3 harbethPQToLinear(float3 color) {
    return float3(
        harbethPQToLinearComponent(color.r),
        harbethPQToLinearComponent(color.g),
        harbethPQToLinearComponent(color.b)
    );
}

static inline float3 harbethLinearToPQ(float3 color) {
    return float3(
        harbethLinearToPQComponent(color.r),
        harbethLinearToPQComponent(color.g),
        harbethLinearToPQComponent(color.b)
    );
}

static inline float3 harbethHLGToLinear(float3 color) {
    return float3(
        harbethHLGToLinearComponent(color.r),
        harbethHLGToLinearComponent(color.g),
        harbethHLGToLinearComponent(color.b)
    );
}

static inline float3 harbethLinearToHLG(float3 color) {
    return float3(
        harbethLinearToHLGComponent(color.r),
        harbethLinearToHLGComponent(color.g),
        harbethLinearToHLGComponent(color.b)
    );
}

kernel void C7RGBTransferConversion(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> inputTexture [[texture(1)]],
                                    constant float *mode [[buffer(0)]],
                                    uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 rgb = float3(input.rgb);
    float3 outputRGB;
    if (*mode < 0.5) {
        outputRGB = harbethSRGBToLinear(rgb);
    } else if (*mode < 1.5) {
        outputRGB = harbethLinearToSRGB(rgb);
    } else if (*mode < 2.5) {
        outputRGB = harbethPQToLinear(rgb);
    } else if (*mode < 3.5) {
        outputRGB = harbethLinearToPQ(rgb);
    } else if (*mode < 4.5) {
        outputRGB = harbethHLGToLinear(rgb);
    } else {
        outputRGB = harbethLinearToHLG(rgb);
    }

    const bool clampOutput = *mode < 2.0f;
    outputTexture.write(half4(half3(clampOutput ? clamp(outputRGB, 0.0, 1.0) : outputRGB), input.a), grid);
}
