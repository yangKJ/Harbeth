//
//  C7AlphaBlend.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7AlphaBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                         constant float *mixturePercent [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(gid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const half4 inColor2 = inputTexture2.sample(quadSampler, float2(float(gid.x) / outputTexture.get_width(), float(gid.y) / outputTexture.get_height()));
    const half4 outColor(mix(inColor.rgb, inColor2.rgb, inColor2.a * half(*mixturePercent)), inColor.a);
    
    outputTexture.write(outColor, gid);
}
