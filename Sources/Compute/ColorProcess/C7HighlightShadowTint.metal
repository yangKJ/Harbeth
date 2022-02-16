//
//  C7HighlightShadowTint.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7HighlightShadowTint(texture2d<half, access::write> outputTexture [[texture(0)]],
                                  texture2d<half, access::read> inputTexture [[texture(1)]],
                                  constant float *shadowTintIntensity [[buffer(0)]],
                                  constant float *shadowTintColorR [[buffer(1)]],
                                  constant float *shadowTintColorG [[buffer(2)]],
                                  constant float *shadowTintColorB [[buffer(3)]],
                                  constant float *highlightTintIntensity [[buffer(4)]],
                                  constant float *highlightTintColorR [[buffer(5)]],
                                  constant float *highlightTintColorG [[buffer(6)]],
                                  constant float *highlightTintColorB [[buffer(7)]],
                                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 shadowTintColor = half3(*shadowTintColorR, *shadowTintColorG, *shadowTintColorB);
    const half3 highlightTintColor = half3(*highlightTintColorR, *highlightTintColorG, *highlightTintColorB);
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    const half4 shadowResult = mix(inColor, max(inColor, half4(mix(shadowTintColor, inColor.rgb, luminance), inColor.a)), half(*shadowTintIntensity));
    const half4 highlightResult = mix(inColor, min(shadowResult, half4(mix(shadowResult.rgb, highlightTintColor, luminance), inColor.a)), half(*highlightTintIntensity));
    const half4 outColor(mix(shadowResult.rgb, highlightResult.rgb, luminance), inColor.a);
    
    outputTexture.write(outColor, grid);
}
