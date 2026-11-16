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
// 每个线程处理一行中最多 64 个像素，列统计按段复用，不分配整图中间纹理。
kernel void C7OilPaintingWindowed(texture2d<float, access::write> destination [[texture(0)]],
    texture2d<float, access::read> source [[texture(1)]], constant float &radius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    int2 extent = int2(source.get_width(), source.get_height());
    int start = int(gid.x) * 64;
    if (start >= extent.x || int(gid.y) >= extent.y) return;
    int r = int(radius), end = min(start + 64, extent.x);
    float4 sums[2], squares[2];
    float n = (radius + 1) * (radius + 1);
    for (int x = start; x < end; ++x) {
        // 定期重建局部和，约束反复相减的误差，仍比逐像素二维扫描少采样。
        if ((x - start) % 16 == 0) {
            for (int k = 0; k < 2; ++k) {
                bool left = k == 0 || k == 3;
                bool top = k < 2;
                sums[k] = 0; squares[k] = 0;
                for (int dy = top ? -r : 0; dy <= (top ? 0 : r); ++dy) {
                    for (int dx = left ? -r : 0; dx <= (left ? 0 : r); ++dx) {
                        float4 c = source.read(uint2(clamp(int2(x + dx, int(gid.y) + dy), int2(0), extent - 1)));
                        sums[k] += c; squares[k] += c * c;
                    }
                }
            }
        }
        float best = 100; float4 result = float4(0, 0, 0, 1);
        for (int k = 0; k < 2; ++k) {
            float4 mean = sums[k] / n;
            float3 variance = abs(squares[k].rgb / n - mean.rgb * mean.rgb);
            float score = variance.r + variance.g + variance.b;
            if (score < best) { best = score; result = float4(mean.rgb, 1); }
        }
        destination.write(result, uint2(x, gid.y));
        if (x + 1 < end && (x + 1 - start) % 16 != 0) {
            for (int k = 0; k < 2; ++k) {
                bool left = k == 0 || k == 3, top = k < 2;
                int leaving = left ? x - r : x;
                int entering = left ? x + 1 : x + r + 1;
                for (int dy = top ? -r : 0; dy <= (top ? 0 : r); ++dy) {
                    int y = clamp(int(gid.y) + dy, 0, extent.y - 1);
                    float4 a = source.read(uint2(clamp(leaving, 0, extent.x - 1), y));
                    float4 b = source.read(uint2(clamp(entering, 0, extent.x - 1), y));
                    sums[k] += b - a; squares[k] += b * b - a * a;
                }
            }
        }
    }
}
