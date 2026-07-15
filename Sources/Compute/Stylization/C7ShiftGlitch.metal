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
                          constant float4 *harbethRegionContext [[buffer(30)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 logicalSize = max(harbethRegionContext->zw, float2(1.0));
    const float2 globalPixel = float2(grid) + harbethRegionContext->xy;
    const float2 textureCoordinate = globalPixel / logicalSize;
    
    const half time = half(*timePointer);
    const float blurX = shift_glitch::noise(float3(time * 10.0, 0.0, 0.0)) * 2.0 - 1.0;
    const float offsetx = blurX * 0.025;
    
    const float blurY = shift_glitch::noise(float3(time * 10.0, 1.0, 0.0)) * 2.0 - 1.0;
    const float offsety = blurY * 0.01;
    
    const half2 ruv = half2(textureCoordinate) + half2(offsetx, offsety);
    const half2 guv = half2(textureCoordinate) + half2(-offsetx, -offsety);
    const half2 buv = half2(textureCoordinate) + half2(0.0h, 0.0h);
    
    float2 rLocalPixel = float2(ruv) * logicalSize - harbethRegionContext->xy;
    float2 gLocalPixel = float2(guv) * logicalSize - harbethRegionContext->xy;
    float2 bLocalPixel = float2(buv) * logicalSize - harbethRegionContext->xy;
    const half r = inputTexture.read(uint2(clamp(rLocalPixel, float2(0.0), inputSize - 1.0))).r;
    const half g = inputTexture.read(uint2(clamp(gLocalPixel, float2(0.0), inputSize - 1.0))).g;
    const half b = inputTexture.read(uint2(clamp(bLocalPixel, float2(0.0), inputSize - 1.0))).b;
    const half4 outColor = half4(r, g, b, 1.0h);
    
    outputTexture.write(outColor, grid);
}
