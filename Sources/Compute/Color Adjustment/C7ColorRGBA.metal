//
//  C7ColorRGBA.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorRGBA(texture2d<float, access::write> outputTexture [[texture(0)]],
                        texture2d<float, access::read> inputTexture [[texture(1)]],
                        constant float *intensity [[buffer(0)]],
                        constant float4 *colorVector [[buffer(1)]],
                        constant float &halfOutput [[buffer(2)]],
                        uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 inColor = inputTexture.read(grid);
    if (!isfinite(*intensity) || *intensity <= 0.0f || all((*colorVector).rgb == float3(1))) { outputTexture.write(halfOutput > 0.5f ? float4(half4(inColor)) : inColor, grid); return; }
    
    const float4 color = float4(*colorVector);
    const float tintAmount = clamp(*intensity, 0.0f, 1.0f);
    const float3 outRGB = inColor.rgb * color.rgb;
    const float3 outputRGB = mix(inColor.rgb, outRGB, tintAmount);
    const float4 output(outputRGB, inColor.a);
    
    outputTexture.write(halfOutput > 0.5f ? float4(half4(output)) : output, grid);
}
