//
//  TextMetal.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

namespace test_1 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_2 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_3 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_4 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_5 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_6 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_7 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_8 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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

namespace test_9 {
    kernel void TextMetal(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          constant float *threshold [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float *red [[buffer(2)]],
                          constant float *green [[buffer(3)]],
                          constant float *blue [[buffer(4)]],
                          uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal2(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal3(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal4(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal5(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal6(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal7(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal8(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
        const half maskCr = 0.7132h * (half(*red) - maskY);
        const half maskCb = 0.5647h * (half(*blue) - maskY);
        
        const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
        const half Cr = 0.7132h * (inColor.r - Y);
        const half Cb = 0.5647h * (inColor.b - Y);
        
        const float blendValue = 1.0 - smoothstep(float(*threshold), float(*threshold) + float(*smoothing), distance(float2(Cr, Cb), float2(maskCr, maskCb)));
        const half4 outColor = half4(mix(inColor, inColor2, half(blendValue)));
        
        outputTexture.write(outColor, grid);
    }
    
    kernel void TextMetal9(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *threshold [[buffer(0)]],
                           constant float *smoothing [[buffer(1)]],
                           constant float *red [[buffer(2)]],
                           constant float *green [[buffer(3)]],
                           constant float *blue [[buffer(4)]],
                           uint2 grid [[thread_position_in_grid]]) {
        const half4 inColor = inputTexture.read(grid);
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
        
        const half maskY  = 0.2989h * half(*red) + 0.5866h * half(*green) + 0.1145h * half(*blue);
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
