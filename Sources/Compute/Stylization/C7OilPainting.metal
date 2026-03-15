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
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *radius [[buffer(0)]],
                          constant float *pixel [[buffer(1)]],
                          uint2 grid [[thread_position_in_grid]]) {
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    
    const float r = float(*radius);
    const float n = float((r + 1.0) * (r + 1.0));
    
    float3 m0 = float3(0.0);
    float3 m1 = float3(0.0);
    float3 s0 = float3(0.0);
    float3 s1 = float3(0.0);
    
    for (int j = -int(r); j <= 0; ++j)  {
        for (int k = -int(r); k <= 0; ++k)  {
            int2 offset = int2(k, j);
            uint2 samplePos = uint2(clamp(int(pos.x) + offset.x, 0, width - 1), 
                                  clamp(int(pos.y) + offset.y, 0, height - 1));
            float3 color = float3(inputTexture.read(samplePos).rgb);
            m0 += color;
            s0 += color * color;
        }
    }
    
    for (int j = -int(r); j <= 0; ++j)  {
        for (int k = 0; k <= int(r); ++k)  {
            int2 offset = int2(k, j);
            uint2 samplePos = uint2(clamp(int(pos.x) + offset.x, 0, width - 1), 
                                  clamp(int(pos.y) + offset.y, 0, height - 1));
            float3 color = float3(inputTexture.read(samplePos).rgb);
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
