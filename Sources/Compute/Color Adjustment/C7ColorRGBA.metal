//
//  C7ColorRGBA.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *intensity [[buffer(0)]],
                        constant float4 *colorVector [[buffer(1)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 color = half4(*colorVector);
    const half tintAmount = clamp(half(*intensity), half(0.0), half(1.0));
    const half3 outRGB = inColor.rgb * color.rgb;
    const half3 outputRGB = mix(inColor.rgb, outRGB, tintAmount);
    const half4 output(outputRGB, inColor.a);
    
    outputTexture.write(output, grid);
}
