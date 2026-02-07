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

namespace shift_glitch {
    METAL_FUNC float hash(float n) {
        return fract(sin(n) * 43758.5453);
    }

    METAL_FUNC float noise(float3 x) {
        float3 p = floor(x);
        float3 f = fract(x);
        f = f * f * (3.0 - 2.0 * f);
        float n = p.x + p.y * 57.0 + 113.0 * p.z;
        float res = mix(mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
                            mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
                        mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                            mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y),
                        f.z);
        return res;
    }
}

kernel void C7ShiftGlitch(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *timePointer [[buffer(0)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const float w = outputTexture.get_width();
    const float h = outputTexture.get_height();
    const float2 textureCoordinate = float2(grid) / float2(w, h);
    
    const half time = half(*timePointer);
    const float blurX = shift_glitch::noise(float3(time * 10.0, 0.0, 0.0)) * 2.0 - 1.0;
    const float offsetx = blurX * 0.025;
    
    const float blurY = shift_glitch::noise(float3(time * 10.0, 1.0, 0.0)) * 2.0 - 1.0;
    const float offsety = blurY * 0.01;
    
    const half2 ruv = half2(textureCoordinate) + half2(offsetx, offsety);
    const half2 guv = half2(textureCoordinate) + half2(-offsetx, -offsety);
    const half2 buv = half2(textureCoordinate) + half2(0.0h, 0.0h);
    
    const half r = inputTexture.read(uint2(ruv * half2(w, h))).r;
    const half g = inputTexture.read(uint2(guv * half2(w, h))).g;
    const half b = inputTexture.read(uint2(buv * half2(w, h))).b;
    const half4 outColor = half4(r, g, b, 1.0h);
    
    outputTexture.write(outColor, grid);
}
