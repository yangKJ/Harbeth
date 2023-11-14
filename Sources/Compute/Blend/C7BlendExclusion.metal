//
//  C7BlendExclusion.metal
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendExclusion(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                             constant float *intensity [[buffer(0)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    const half3 excolor = half3(overlay.rgb * inColor.a + inColor.rgb * overlay.a - 2.0h * overlay.rgb * inColor.rgb) + overlay.rgb * (1.0h - inColor.a) + inColor.rgb * (1.0h - overlay.a);
    const half4 outColor = half4(excolor, inColor.a);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
