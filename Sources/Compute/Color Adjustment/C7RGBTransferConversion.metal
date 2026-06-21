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

kernel void C7RGBTransferConversion(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> inputTexture [[texture(1)]],
                                    constant float *mode [[buffer(0)]],
                                    uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 rgb = float3(input.rgb);
    const float3 outputRGB = (*mode < 0.5)
        ? harbethSRGBToLinear(rgb)
        : harbethLinearToSRGB(rgb);

    outputTexture.write(half4(half3(clamp(outputRGB, 0.0, 1.0)), input.a), grid);
}
