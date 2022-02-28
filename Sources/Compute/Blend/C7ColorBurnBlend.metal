//
//  C7ColorBurnBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorBurnBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    const half4 whiteColor = half4(1.0h);
    const half4 outColor = whiteColor - (whiteColor - inColor) / inColor2;
    
    outputTexture.write(outColor, grid);
}
