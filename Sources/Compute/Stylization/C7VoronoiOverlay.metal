//
//  C7VoronoiOverlay.metal
//  Harbeth
//
//  Created by Condy on 2022/3/1.
//

// 效果来源
// https://www.shadertoy.com/view/MdSGRc

#include <metal_stdlib>
using namespace metal;

namespace voronoi {
    METAL_FUNC float2 hash2(float2 p) {
        p = float2(dot(p, float2(127.1,311.7)), dot(p, float2(269.5,183.3)));
        return fract(sin(p) * 43758.5453);
    }

    METAL_FUNC float4 voronoi(float2 x, float mode, float iTime) {
        float2 n = floor(x);
        float2 f = fract(x);
        float3 m = float3(8.0);
        float m2 = 8.0;
        for (int j=-2; j<=2; j++) {
            for (int i=-2; i<=2; i++) {
                float2 g = float2(float(i),float(j));
                float2 o = hash2(n + g);
                // 格点动画
                o = 0.5 + 0.5*sin(iTime + 6.2831*o);
                float2 r = g - f + o;
                // 欧氏距离
                float2 d0 = float2(sqrt(dot(r,r)), 1.0);
                // 曼哈顿距离
                float2 d1 = float2(0.71*(abs(r.x) + abs(r.y)), 1.0);
                // 三角距离
                float2 d2 = float2(max(abs(r.x)*0.866025+r.y*0.5,-r.y), step(0.0,0.5*abs(r.x)+0.866025*r.y)*(1.0+step(0.0,r.x)));
                float2 d = d0;
                if (mode<3.0) d = mix(d2, d0, fract(mode));
                if (mode<2.0) d = mix(d1, d2, fract(mode));
                if (mode<1.0) d = mix(d0, d1, fract(mode));
                if (d.x<m.x) {
                    m2 = m.x;
                    m.x = d.x;
                    const float nb = (dot(n+g,float2(7.0,113.0)));
                    m.y = fract(sin(nb) * 43758.5453);
                    m.z = d.y;
                } else if(d.x<m2) {
                    m2 = d.x;
                }
            }
        }
        return float4(m, m2-m.x);
    }
    METAL_FUNC float4 fieldVoronoi(float2 x, float mode, texture2d<float, access::read> field) {
        float2 n = floor(x);
        float2 f = fract(x);
        float3 m = float3(8.0);
        float m2 = 8.0;
        for (int j=-2; j<=2; j++) {
            for (int i=-2; i<=2; i++) {
                float2 g = float2(float(i),float(j));
                const float4 cell = field.read(uint2(int2(n + g) + int2(2)));
                float2 o = cell.xy;
                float2 r = g - f + o;
                // 欧氏距离
                float2 d0 = float2(sqrt(dot(r,r)), 1.0);
                // 曼哈顿距离
                float2 d1 = float2(0.71*(abs(r.x) + abs(r.y)), 1.0);
                // 三角距离
                float2 d2 = float2(max(abs(r.x)*0.866025+r.y*0.5,-r.y), step(0.0,0.5*abs(r.x)+0.866025*r.y)*(1.0+step(0.0,r.x)));
                float2 d = d0;
                if (mode<3.0) d = mix(d2, d0, fract(mode));
                if (mode<2.0) d = mix(d1, d2, fract(mode));
                if (mode<1.0) d = mix(d0, d1, fract(mode));
                if (d.x<m.x) {
                    m2 = m.x;
                    m.x = d.x;
                    m.y = cell.z;
                    m.z = d.y;
                } else if(d.x<m2) {
                    m2 = d.x;
                }
            }
        }
        return float4(m, m2-m.x);
    }
}

kernel void C7VoronoiOverlay(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             constant float *timePointer [[buffer(0)]],
                             constant float *alphaPointer [[buffer(1)]],
                             constant float *iResolutionX [[buffer(2)]],
                             constant float *iResolutionY [[buffer(3)]],
                             constant float4 *regionContext [[buffer(30)]],
                             constant float &halfOutput [[buffer(4)]],
                             uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 inColor = inputTexture.read(grid);
    if (*alphaPointer == 0.0f) { outputTexture.write(inColor, grid); return; }
    const float4 outputRegion = regionContext[1];
    const float2 textureCoordinate = (float2(grid) + outputRegion.xy) / outputRegion.zw;

    const float iTime = float(*timePointer);
    const float alpha = *alphaPointer;
    const float3 iResolution = float3(*iResolutionX, *iResolutionY, 1);

    float mode = fmod(iTime/5.0, 3.0);
    mode = floor(mode) + smoothstep(0.8, 1.0, fract(mode));

    float2 p = textureCoordinate.xy / iResolution.xx;
    float4 c = voronoi::voronoi(8.0*p, mode, iTime);

    float3 col = 0.5 + 0.5*sin(c.y*2.5 + float3(1.0,1.0,1.9));
    col *= sqrt(clamp(1.0 - c.x, 0.0, 1.0));
    col *= clamp(0.5 + (1.0-c.z/2.0)*0.5, 0.0, 1.0);
    col *= 0.4 + 0.6*sqrt(clamp(4.0*c.w, 0.0, 1.0));

    const float4 outColor = inColor * (1.0f - alpha) + float4(col * alpha, alpha);

    outputTexture.write(halfOutput > 0.5f ? float4(half4(outColor)) : outColor, grid);
}

// 每次命令生成自己的格点表，不跨在途命令共享可写表面。
kernel void voronoiBuildCells(texture2d<float, access::write> field [[texture(0)]],
                             constant float &time [[buffer(0)]], uint2 p [[thread_position_in_grid]]) {
    if (p.x >= field.get_width() || p.y >= field.get_height()) return;
    const float2 cell = float2(int2(p) - int2(2));
    const float2 offset = 0.5 + 0.5 * sin(time + 6.2831 * voronoi::hash2(cell));
    const float label = fract(sin(dot(cell, float2(7.0, 113.0))) * 43758.5453);
    field.write(float4(offset, label, 0), p);
}

kernel void C7VoronoiOverlayField(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             texture2d<float, access::read> field [[texture(2)]],
                             constant float *timePointer [[buffer(0)]],
                             constant float *alphaPointer [[buffer(1)]],
                             constant float *iResolutionX [[buffer(2)]],
                             constant float *iResolutionY [[buffer(3)]],
                             constant float4 *regionContext [[buffer(30)]],
                             constant float &halfOutput [[buffer(4)]],
                             uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 inColor = inputTexture.read(grid);
    if (*alphaPointer == 0.0f) { outputTexture.write(inColor, grid); return; }
    const float4 outputRegion = regionContext[1];
    const float2 textureCoordinate = (float2(grid) + outputRegion.xy) / outputRegion.zw;

    const float iTime = float(*timePointer);
    const float alpha = *alphaPointer;
    const float3 iResolution = float3(*iResolutionX, *iResolutionY, 1);

    float mode = fmod(iTime/5.0, 3.0);
    mode = floor(mode) + smoothstep(0.8, 1.0, fract(mode));

    float2 p = textureCoordinate.xy / iResolution.xx;
    float4 c = voronoi::fieldVoronoi(8.0*p, mode, field);

    float3 col = 0.5 + 0.5*sin(c.y*2.5 + float3(1.0,1.0,1.9));
    col *= sqrt(clamp(1.0 - c.x, 0.0, 1.0));
    col *= clamp(0.5 + (1.0-c.z/2.0)*0.5, 0.0, 1.0);
    col *= 0.4 + 0.6*sqrt(clamp(4.0*c.w, 0.0, 1.0));

    const float4 outColor = inColor * (1.0f - alpha) + float4(col * alpha, alpha);

    outputTexture.write(halfOutput > 0.5f ? float4(half4(outColor)) : outColor, grid);
}
