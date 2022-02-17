//
//  C7HighlightShadow.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7HighlightShadow(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *shadows [[buffer(0)]],
                              constant float *highlights [[buffer(1)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    const half shadow = clamp((pow(luminance, 1.0h / (half(*shadows) + 1.0h)) + (-0.76) * pow(luminance, 2.0h / (half(*shadows) + 1.0h))) - luminance, 0.0, 1.0);
    const half highlight = clamp((1.0 - (pow(1.0 - luminance, 1.0 / (2.0 - half(*highlights))) + (-0.8) * pow(1.0 - luminance, 2.0 / (2.0 - half(*highlights))))) - luminance, -1.0, 0.0);
    const half3 result = half3(0.0, 0.0, 0.0) + ((luminance + shadow + highlight) - 0.0) * ((inColor.rgb - half3(0.0, 0.0, 0.0)) / (luminance - 0.0));
    const half4 outColor = half4(result.rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
