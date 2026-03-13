//
//  C7Fade.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Fade(texture2d<half, access::write> outputTexture [[texture(0)]],
                  texture2d<half, access::read> inputTexture [[texture(1)]],
                  constant float *intensity [[buffer(0)]],
                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    float fadeIntensity = *intensity;
    
    // 计算淡出颜色，从原始颜色过渡到白色
    half4 outColor;
    outColor.rgb = mix(inColor.rgb, half3(1.0), half(fadeIntensity));
    outColor.a = inColor.a;
    
    outputTexture.write(outColor, grid);
}