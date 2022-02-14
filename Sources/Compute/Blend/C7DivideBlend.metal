//
//  C7DivideBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7DivideBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 overlay = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    
    half ra;
    if (overlay.a == 0.0h || ((inColor.r / overlay.r) > (inColor.a / overlay.a))) {
        ra = overlay.a * inColor.a + overlay.r * (1.0h - inColor.a) + inColor.r * (1.0h - overlay.a);
    } else {
        ra = (inColor.r * overlay.a * overlay.a) / overlay.r + overlay.r * (1.0h - inColor.a) + inColor.r * (1.0h - overlay.a);
    }
    
    half ga;
    if (overlay.a == 0.0h || ((inColor.g / overlay.g) > (inColor.a / overlay.a))) {
        ga = overlay.a * inColor.a + overlay.g * (1.0h - inColor.a) + inColor.g * (1.0h - overlay.a);
    } else {
        ga = (inColor.g * overlay.a * overlay.a) / overlay.g + overlay.g * (1.0h - inColor.a) + inColor.g * (1.0h - overlay.a);
    }
    
    half ba;
    if (overlay.a == 0.0h || ((inColor.b / overlay.b) > (inColor.a / overlay.a))) {
        ba = overlay.a * inColor.a + overlay.b * (1.0h - inColor.a) + inColor.b * (1.0h - overlay.a);
    } else {
        ba = (inColor.b * overlay.a * overlay.a) / overlay.b + overlay.b * (1.0h - inColor.a) + inColor.b * (1.0h - overlay.a);        
    }
    
    const half a = overlay.a + inColor.a - overlay.a * inColor.a;
    
    const half4 outColor(ra, ga, ba, a);
    outputTexture.write(outColor, grid);
}

