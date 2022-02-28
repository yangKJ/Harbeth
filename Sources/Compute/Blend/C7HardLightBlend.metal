//
//  C7HardLightBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7HardLightBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 overlay = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    
    half ra;
    if (2.0h * overlay.r < overlay.a) {
        ra = 2.0h * overlay.r * inColor.r + overlay.r * (1.0h - inColor.a) + inColor.r * (1.0h - overlay.a);
    } else {
        ra = overlay.a * inColor.a - 2.0h * (inColor.a - inColor.r) * (overlay.a - overlay.r) + overlay.r * (1.0h - inColor.a) + inColor.r * (1.0h - overlay.a);
    }
    
    half ga;
    if (2.0h * overlay.g < overlay.a) {
        ga = 2.0h * overlay.g * inColor.g + overlay.g * (1.0h - inColor.a) + inColor.g * (1.0h - overlay.a);
    } else {
        ga = overlay.a * inColor.a - 2.0h * (inColor.a - inColor.g) * (overlay.a - overlay.g) + overlay.g * (1.0h - inColor.a) + inColor.g * (1.0h - overlay.a);
    }
    
    half ba;
    if (2.0h * overlay.b < overlay.a) {
        ba = 2.0h * overlay.b * inColor.b + overlay.b * (1.0h - inColor.a) + inColor.b * (1.0h - overlay.a);
    } else {
        ba = overlay.a * inColor.a - 2.0h * (inColor.a - inColor.b) * (overlay.a - overlay.b) + overlay.b * (1.0h - inColor.a) + inColor.b * (1.0h - overlay.a);
    }
    
    const half4 outColor = half4(ra, ga, ba, 1.0h);
    outputTexture.write(outColor, grid);
}
