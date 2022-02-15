//
//  C7DepthLuminance.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7DepthLuminance(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             constant float *offset [[buffer(0)]],
                             constant float *range [[buffer(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const float4 textureCoordinate = inputTexture.read(grid);
    
    float depth = textureCoordinate.x;
    // Normalize the value between 0 and 1.
    depth = (depth - *offset) / (*range);
    
    const float4 outputColor = float4(float3(depth), 1.0);
    
    outputTexture.write(outputColor, grid);
}
