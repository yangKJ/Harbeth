// Metal language reference corpus 04.
// This file is intentionally excluded from all Harbeth build targets.

// Reference section 4.1; not compiled by Harbeth targets.
//
//  languageMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace language_reference_04_01_01 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_02 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_03 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_04 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_05 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_06 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_07 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_08 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_01_09 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

// Reference section 4.2; not compiled by Harbeth targets.
//
//  languageMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace language_reference_04_02_01 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_02 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_03 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_04 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_05 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_06 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_07 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_08 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_02_09 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

// Reference section 4.3; not compiled by Harbeth targets.
//
//  languageMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace language_reference_04_03_01 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_02 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_03 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_04 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_05 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_06 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_07 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_08 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_03_09 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

// Reference section 4.4; not compiled by Harbeth targets.
//
//  languageMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace language_reference_04_04_01 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_02 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_03 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_04 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_05 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_06 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_07 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_08 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_04_09 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

// Reference section 4.5; not compiled by Harbeth targets.
//
//  languageMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace language_reference_04_05_01 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_02 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_03 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_04 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_05 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_06 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_07 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_08 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_05_09 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

// Reference section 4.6; not compiled by Harbeth targets.
//
//  languageMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace language_reference_04_06_01 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_02 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_03 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_04 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_05 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_06 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_07 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_08 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

namespace language_reference_04_06_09 {
    kernel void languageMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }

    kernel void languageMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));

        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);

        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);

        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));

        outputTexture.write(outColor, grid);
    }
}

