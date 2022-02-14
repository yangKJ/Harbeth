//
//  C7ColorDodgeBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorDodgeBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 overlay = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    const half3 baseOverlayAlphaProduct = half3(overlay.a * inColor.a);
    const half3 rightHandProduct = overlay.rgb * (1.0h - inColor.a) + inColor.rgb * (1.0h - overlay.a);
    const half3 firstBlendColor = baseOverlayAlphaProduct + rightHandProduct;
    const half3 overlayRGB = clamp((overlay.rgb / clamp(overlay.a, 0.01h, 1.0h)) * step(0.0h, overlay.a), 0.0h, 0.99h);
    const half3 secondBlendColor = (inColor.rgb * overlay.a) / (1.0h - overlayRGB) + rightHandProduct;
    const half3 colorChoice = step((overlay.rgb * inColor.a + inColor.rgb * overlay.a), baseOverlayAlphaProduct);
    
    const half4 outColor(mix(firstBlendColor, secondBlendColor, colorChoice), 1.0h);
    outputTexture.write(outColor, grid);
}

