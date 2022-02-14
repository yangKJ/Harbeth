//
//  C7AddBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7AddBlend(texture2d<half, access::write> outTexture [[texture(0)]],
                       texture2d<half, access::read> inTexture [[texture(1)]],
                       texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 overlay = inputTexture2.sample(quadSampler, float2(float(grid.x) / outTexture.get_width(), float(grid.y) / outTexture.get_height()));
    
    half r;
    if (overlay.r * inColor.a + inColor.r * overlay.a >= overlay.a * inColor.a) {
        r = overlay.a * inColor.a + overlay.r * (1.0h - inColor.a) + inColor.r * (1.0h - overlay.a);
    } else {
        r = overlay.r + inColor.r;
    }
    
    half g;
    if (overlay.g * inColor.a + inColor.g * overlay.a >= overlay.a * inColor.a) {
        g = overlay.a * inColor.a + overlay.g * (1.0h - inColor.a) + inColor.g * (1.0h - overlay.a);
    } else {
        g = overlay.g + inColor.g;
    }
    
    half b;
    if (overlay.b * inColor.a + inColor.b * overlay.a >= overlay.a * inColor.a) {
        b = overlay.a * inColor.a + overlay.b * (1.0h - inColor.a) + inColor.b * (1.0h - overlay.a);
    } else {
        b = overlay.b + inColor.b;
    }
    
    const half a = overlay.a + inColor.a - overlay.a * inColor.a;
    
    const half4 outColor(r, g, b, a);
    outTexture.write(outColor, grid);
}
