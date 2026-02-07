//
//  C7BlendColorAdd.metal
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendColorAdd(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inTexture [[texture(1)]],
                            texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                            constant float *intensity [[buffer(0)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    const bool rbool = overlay.r * inColor.a + inColor.r * overlay.a >= overlay.a * inColor.a;
    const bool gbool = overlay.g * inColor.a + inColor.g * overlay.a >= overlay.a * inColor.a;
    const bool bbool = overlay.b * inColor.a + inColor.b * overlay.a >= overlay.a * inColor.a;
    const half xa = overlay.a * inColor.a;
    const half r = rbool ? (xa + overlay.r * (1.0h - inColor.a) + inColor.r * (1.0h - overlay.a)) : (overlay.r + inColor.r);
    const half g = gbool ? (xa + overlay.g * (1.0h - inColor.a) + inColor.g * (1.0h - overlay.a)) : (overlay.g + inColor.g);
    const half b = bbool ? (xa + overlay.b * (1.0h - inColor.a) + inColor.b * (1.0h - overlay.a)) : (overlay.b + inColor.b);
    const half a = overlay.a + inColor.a - xa;
    
    const half4 outColor = half4(r, g, b, a);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
