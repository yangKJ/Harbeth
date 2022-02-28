//
//  C7SubtractBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SubtractBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height()));
    const half4 outColor = half4(inColor.rgb - inColor2.rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
