//
//  C7MeanBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

// 均值模糊原理其实很简单通过多个纹理叠加，每个纹理偏移量设置不同达到一点重影效果来实现模糊
kernel void C7MeanBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::sample> inputTexture [[texture(1)]],
                       constant float *blurRadius [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 coordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half radius = half(*blurRadius) / 100.0h;
    
    const half4 sample1 = inputTexture.sample(quadSampler, float2(coordinate.x - radius, coordinate.y - radius));
    const half4 sample2 = inputTexture.sample(quadSampler, float2(coordinate.x + radius, coordinate.y + radius));
    const half4 sample3 = inputTexture.sample(quadSampler, float2(coordinate.x + radius, coordinate.y - radius));
    const half4 sample4 = inputTexture.sample(quadSampler, float2(coordinate.x - radius, coordinate.y + radius));
    
    const half4 outColor = (sample1 + sample2 + sample3 + sample4) / 4.0h;
    outputTexture.write(outColor, grid);
}
