//
//  Common.metal
//  Harbeth
//
//  Created by Condy on 2022/6/20.
//

#include <metal_stdlib>
using namespace metal;

namespace common {
    METAL_FUNC float pi(void) {
        return 3.14159265358979323846264338327950288;
    }
    
    METAL_FUNC float N11(float v) {
        return fract(sin(v) * 43758.5453123);
    }
    
    METAL_FUNC float N21(float2 p) {
        return common::N11(dot(p, float2(12.9898, 78.233)));
    }
    
    METAL_FUNC float3 hsv2rgb(float h, float s, float v) {
        float3 a = fract(h + float3(0.0, 2.0, 1.0)/3.0)*6.0-3.0;
        a = clamp(abs(a) - 1.0, 0.0, 1.0) - 1.0;
        a = a * s + 1.0;
        return a * v;
    }
    
    METAL_FUNC float mod(float a, float b) {
        return a - b * floor(a / b);
    }
    
    METAL_FUNC float grid(float2 p) {
        float g = 0.0;
        p = fract(p);
        g = max(g, step(0.98, p.x));
        g = max(g, step(0.98, p.y));
        return g;
    }
    
    METAL_FUNC float rand(float2 n) {
        return fract(sin(cos(dot(n, float2(12.9898, 12.1414)))) * 83758.5453);
    }
    
    METAL_FUNC float3 mod(float3 x, float3 y) {
        return x - y * floor(x / y);
    }
    
    METAL_FUNC float deg2rad(float num) {
        return num * M_PI_F / 180.0;
    }
    
    // 边缘检测
    METAL_FUNC half4 edge(texture2d<half, access::sample> texture, float x, float y, float w, float h) {
        // 边缘检测矩阵卷积核
        const half3x3 matrix = half3x3({-1.0, -1.0, -1.0}, {-1.0,  8.0, -1.0}, {-1.0, -1.0, -1.0});
        constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
        half4 result = half4(0.0h);
        for (int i = 0; i < 9; i++) {
            int a = i % 3; int b = i / 3;
            const half4 sample = texture.sample(quadSampler, float2(x + (a - 3/2.0) / w, y + (b - 3/2.0) / h));
            result += sample * matrix[a][b];
        }
        return result;
    }
}
