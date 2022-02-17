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
                             constant float *range [[buffer(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 textureCoordinate = inputTexture.read(grid);
    
    half depth = textureCoordinate.x;
    // Normalize the value between 0 and 1.
    depth = (depth - half(*offset)) / half(*range);
    
    const half4 outputColor = half4(half3(depth), 1.0h);
    
    outputTexture.write(outputColor, grid);
}
