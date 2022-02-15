//
//  C7Luminance.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Luminance(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        device float *luminance [[buffer(0)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721); // 亮度常量
    const half _luminance = dot(inColor.rgb, luminanceWeighting);
    const half4 outColor = half4(mix(half3(_luminance), inColor.rgb, half3(*luminance)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
