//
//  C7ShiftGlitch.metal
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

// 效果来源
// https://www.shadertoy.com/view/4t23Rc

#include <metal_stdlib>
using namespace metal;

float C7ShiftGlitchHash(float n);
float C7ShiftGlitchNoise(float3 x);

kernel void C7ShiftGlitch(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::sample> inputTexture [[texture(1)]],
                          constant float *timePointer [[buffer(0)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half time = half(*timePointer);
    const float blurx = C7ShiftGlitchNoise(float3(time * 10.0, 0.0, 0.0)) * 2.0 - 1.0;
    const float offsetx = blurx * 0.025;
    
    const float blury = C7ShiftGlitchNoise(float3(time * 10.0, 1.0, 0.0)) * 2.0 - 1.0;
    const float offsety = blury * 0.01;
    
    const float2 ruv = textureCoordinate + float2(offsetx, offsety);
    const float2 guv = textureCoordinate + float2(-offsetx, -offsety);
    const float2 buv = textureCoordinate + float2(0.0, 0.0);
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half r = inputTexture.sample(quadSampler, ruv * textureCoordinate).r;
    const half g = inputTexture.sample(quadSampler, guv * textureCoordinate).g;
    const half b = inputTexture.sample(quadSampler, buv * textureCoordinate).b;
    const half4 outColor = half4(r, g, b, 1.0h);
    
    outputTexture.write(outColor, grid);
}

float C7ShiftGlitchHash(float n) {
    return fract(sin(n) * 43758.5453);
}

float C7ShiftGlitchNoise(float3 x) {
    float3 p = floor(x);
    float3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0 + 113.0 * p.z;
    float res = mix(mix(mix(C7ShiftGlitchHash(n + 0.0), C7ShiftGlitchHash(n + 1.0), f.x),
                        mix(C7ShiftGlitchHash(n + 57.0), C7ShiftGlitchHash(n + 58.0), f.x), f.y),
                    mix(mix(C7ShiftGlitchHash(n + 113.0), C7ShiftGlitchHash(n + 114.0), f.x),
                        mix(C7ShiftGlitchHash(n + 170.0), C7ShiftGlitchHash(n + 171.0), f.x), f.y), f.z);
    return res;
}
