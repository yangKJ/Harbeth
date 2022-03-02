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
                // animate
                o = 0.5 + 0.5*sin(iTime + 6.2831*o);
                float2 r = g - f + o;
                // euclidean
                float2 d0 = float2(sqrt(dot(r,r)), 1.0);
                // manhattam
                float2 d1 = float2(0.71*(abs(r.x) + abs(r.y)), 1.0);
                // triangular
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
}

kernel void C7VoronoiOverlay(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *timePointer [[buffer(0)]],
                             constant float *alphaPointer [[buffer(1)]],
                             constant float *iResolutionX [[buffer(2)]],
                             constant float *iResolutionY [[buffer(3)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float w = outputTexture.get_width();
    const float h = outputTexture.get_height();
    const float2 textureCoordinate = float2(grid) / float2(w, h);
    
    const float iTime = float(*timePointer);
    const half alpha = half(*alphaPointer);
    const float3 iResolution = float3(*iResolutionX, *iResolutionY, 1);
    
    float mode = fmod(iTime/5.0, 3.0);
    mode = floor(mode) + smoothstep(0.8, 1.0, fract(mode));
    
    float2 p = textureCoordinate.xy / iResolution.xx;
    float4 c = voronoi::voronoi(8.0*p, mode, iTime);
    
    float3 col = 0.5 + 0.5*sin(c.y*2.5 + float3(1.0,1.0,1.9));
    col *= sqrt(clamp(1.0 - c.x, 0.0, 1.0));
    col *= clamp(0.5 + (1.0-c.z/2.0)*0.5, 0.0, 1.0);
    col *= 0.4 + 0.6*sqrt(clamp(4.0*c.w, 0.0, 1.0));
    
    const half4 voronoiColor = half4(half3(col), alpha);
    const half4 outColor = inColor * (1.0h - alpha) + voronoiColor;
    
    outputTexture.write(outColor, grid);
}
