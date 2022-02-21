//
//  C7Saturation.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Saturation(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *saturation [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    const half4 outColor = half4(mix(half3(luminance), inColor.rgb, half(*saturation)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
