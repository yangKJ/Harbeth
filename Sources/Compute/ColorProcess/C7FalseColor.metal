//
//  C7FalseColor.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7FalseColor(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float3 *firstVector [[buffer(0)]],
                         constant float3 *secondVector [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    const half3 color1 = half3(*firstVector);
    const half3 color2 = half3(*secondVector);
    const half4 outColor = half4(mix(color1.rgb, color2.rgb, half3(luminance)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
