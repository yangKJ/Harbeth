//
//  C7RGBColorSpaceConversion.metal
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

#include <metal_stdlib>
using namespace metal;

static inline float harbethColorSRGBToLinearComponent(float value) {
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}

static inline float harbethColorLinearToSRGBComponent(float value) {
    return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}

static inline float3 harbethColorSRGBToLinear(float3 color) {
    return float3(
        harbethColorSRGBToLinearComponent(color.r),
        harbethColorSRGBToLinearComponent(color.g),
        harbethColorSRGBToLinearComponent(color.b)
    );
}

static inline float3 harbethLinearToSRGB(float3 color) {
    return float3(
        harbethColorLinearToSRGBComponent(color.r),
        harbethColorLinearToSRGBComponent(color.g),
        harbethColorLinearToSRGBComponent(color.b)
    );
}

static inline float3 harbethLinearSRGBToDisplayP3(float3 color) {
    const float3x3 matrix = float3x3(
        float3(0.8224621, 0.0331941, 0.0170827),
        float3(0.1775379, 0.9668059, 0.0723974),
        float3(0.0, 0.0, 0.9105199)
    );
    return matrix * color;
}

static inline float3 harbethLinearDisplayP3ToSRGB(float3 color) {
    const float3x3 matrix = float3x3(
        float3(1.2249401, -0.0420569, -0.0196376),
        float3(-0.2249404, 1.0420571, -0.0786361),
        float3(0.0, 0.0, 1.0982735)
    );
    return matrix * color;
}

kernel void C7RGBColorSpaceConversion(texture2d<half, access::write> outputTexture [[texture(0)]],
                                      texture2d<half, access::read> inputTexture [[texture(1)]],
                                      constant float *mode [[buffer(0)]],
                                      uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 inputRGB = float3(input.rgb);
    float3 outputRGB;
    bool clampOutput = false;

    if (*mode < 0.5) {
        outputRGB = harbethLinearToSRGB(
            harbethLinearSRGBToDisplayP3(
                harbethColorSRGBToLinear(inputRGB)
            )
        );
        clampOutput = true;
    } else if (*mode < 1.5) {
        outputRGB = harbethLinearToSRGB(
            harbethLinearDisplayP3ToSRGB(
                harbethColorSRGBToLinear(inputRGB)
            )
        );
        clampOutput = true;
    } else if (*mode < 2.5) {
        outputRGB = harbethLinearDisplayP3ToSRGB(
            harbethColorSRGBToLinear(inputRGB)
        );
    } else {
        outputRGB = harbethLinearToSRGB(
            harbethLinearSRGBToDisplayP3(inputRGB)
        );
        clampOutput = true;
    }

    if (clampOutput) {
        outputRGB = clamp(outputRGB, 0.0, 1.0);
    }
    outputTexture.write(half4(half3(outputRGB), input.a), grid);
}
