//
//  C7Haze.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Haze(texture2d<float, access::write> outputTexture [[texture(0)]],
                   texture2d<float, access::read> inputTexture [[texture(1)]],
                   constant float *hazeDistance [[buffer(0)]],
                   constant float *slope [[buffer(1)]],
                   constant float &halfOutput [[buffer(2)]],
                   constant float4 *regionContext [[buffer(30)]],
                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 inColor = inputTexture.read(grid);
    const float globalY = float(grid.y) + regionContext[1].y;
    const float logicalHeight = max(regionContext[1].w, 1.0f);
    const float dd = globalY / logicalHeight * (*slope) + (*hazeDistance);
    // 奇异点旁路；普通参数继续采用原来的四通道去雾方程。
    float4 result = inColor;
    if (isfinite(dd) && dd != 1.0f && dd != 0.0f) result = (inColor - dd) / (1.0f - dd);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
