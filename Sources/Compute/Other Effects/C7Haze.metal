//
//  C7Haze.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Haze(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::read> inputTexture [[texture(1)]],
                   constant float *hazeDistance [[buffer(0)]],
                   constant float *slope [[buffer(1)]],
                   constant float4 *regionContext [[buffer(30)]],
                   uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float globalY = float(grid.y) + regionContext[1].y;
    const float logicalHeight = max(regionContext[1].w, 1.0);
    
    const half4 white = half4(1.0h);
    const half dd = half(globalY / logicalHeight) * half(*slope) + half(*hazeDistance);
    const half4 outColor = half4((inColor - dd * white) / (1.0h - dd));
    
    outputTexture.write(outColor, grid);
}
