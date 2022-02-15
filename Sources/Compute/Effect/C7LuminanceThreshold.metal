//
//  C7LuminanceThreshold.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

// 阈值滤镜 阈值的大小是动态（根据图片情况）
kernel void C7LuminanceThreshold(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 device float *threshold [[buffer(0)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721); // 亮度常量
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    
    // step luminance >= half(*threshold) 的值为1，小于则为0
    half thresholdResult = step(half(*threshold), luminance);
    const half4 outColor = half4(half3(thresholdResult), inColor.w);
    
    outputTexture.write(outColor, grid);
}
