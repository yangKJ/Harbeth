//
//  C7LuminanceRangeReduction.metal
//  Harbeth
//
//  Created by Condy on 2022/2/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LuminanceRangeReduction(texture2d<half, access::write> outputTexture [[texture(0)]],
                                      texture2d<half, access::read> inputTexture [[texture(1)]],
                                      device float *rangeReductionFactor [[buffer(0)]],
                                      uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721); // 亮度常量
    const half _luminance = dot(inColor.rgb, luminanceWeighting);
    half luminanceRatio = ((0.5h - _luminance) * half(*rangeReductionFactor));
    const half4 outColor = half4(half3((inColor.rgb) + (luminanceRatio)), inColor.w);
    
    outputTexture.write(outColor, grid);
}
