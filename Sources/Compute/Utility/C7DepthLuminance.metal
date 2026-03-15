//
//  C7DepthLuminance.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7DepthLuminance(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *offset [[buffer(0)]],
                             constant float *depthRange [[buffer(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inputColor = inputTexture.read(grid);
    
    half luminance = 0.2126 * inputColor.r + 0.7152 * inputColor.g + 0.0722 * inputColor.b;
    half depth = (luminance - half(*offset)) / half(*depthRange);
    depth = clamp(depth, 0.0h, 1.0h);
    depth = 1.0h - depth;
    
    const half4 outputColor = half4(half3(depth), 1.0h);
    
    outputTexture.write(outputColor, grid);
}
