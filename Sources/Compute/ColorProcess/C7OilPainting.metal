//
//  C7OilPainting.metal
//  Harbeth
//
//  Created by Condy on 2022/3/29.
//

// 算法来源：https://blog.csdn.net/qq_37340753/article/details/104975346

#include <metal_stdlib>
using namespace metal;

kernel void C7OilPainting(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::sample> inputTexture [[texture(1)]],
                          constant float *radius [[buffer(0)]],
                          constant float *pixel [[buffer(1)]],
                          uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 size = float2(*pixel) / float2(outputTexture.get_width(), outputTexture.get_height());
    const float2 textureCoordinate = float2(grid) / float2(outputTexture.get_width(), outputTexture.get_height());
    const float r = float(*radius);
    const float n = float((r + 1.0) * (r + 1.0));
    
    float3 m0 = float3(0.0);
    float3 m1 = float3(0.0);
    float3 s0 = float3(0.0);
    float3 s1 = float3(0.0);
    float3 color = float3(0.0);
    
    for (float j = -r; j <= 0.0; ++j)  {
        for (float k = -r; k <= 0.0; ++k)  {
            color = float3(inputTexture.sample(quadSampler, textureCoordinate + float2(k,j) * size).rgb);
            m0 += color;
            s0 += color * color;
        }
    }
    
    for (float j = -r; j <= 0.0; ++j)  {
        for (float k = 0.0; k <= r; ++k)  {
            color = float3(inputTexture.sample(quadSampler, textureCoordinate + float2(k,j) * size).rgb);
            m1 += color;
            s1 += color * color;
        }
    }
    
    half4 outColor = half4(0.0h);
    float min_sigma2 = 100.0;
    m0 /= n;
    s0 = abs(s0 / n - m0 * m0);
    float sigma2 = s0.r + s0.g + s0.b;
    if (sigma2 < min_sigma2) {
        min_sigma2 = sigma2;
        outColor = half4(half3(m0), 1.0h);
    }
    
    m1 /= n;
    s1 = abs(s1 / n - m1 * m1);
    sigma2 = s1.r + s1.g + s1.b;
    if (sigma2 < min_sigma2) {
        min_sigma2 = sigma2;
        outColor = half4(half3(m1), 1.0h);
    }
    
    outputTexture.write(outColor, grid);
}
