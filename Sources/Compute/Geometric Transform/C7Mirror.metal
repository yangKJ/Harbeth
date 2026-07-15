//
//  C7Mirror.metal
//  Harbeth
//
//  Created by Condy on 2025/7/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Mirror(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float4 *regionContext [[buffer(30)]],
                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) { return; }
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float2 globalOutput = float2(grid) + outputRegion.xy;
    const float2 globalInput = float2(inputRegion.z - 1.0 - globalOutput.x, globalOutput.y);
    const int2 localInput = int2(round(globalInput - inputRegion.xy));
    if (localInput.x < 0 || localInput.y < 0 ||
        localInput.x >= int(inputTexture.get_width()) || localInput.y >= int(inputTexture.get_height())) {
        outputTexture.write(half4(0), grid);
        return;
    }
    const half4 outColor = inputTexture.read(uint2(localInput));
    outputTexture.write(outColor, grid);
}
