//
//  C7BlendHardMix.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendHardMix(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                           constant float *intensity [[buffer(0)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    
    // Hard Mix: 将颜色简化为纯黑或纯白
    for (int i = 0; i < 3; i++) {
        if (inColor[i] + overlay[i] > 1.0) {
            outColor[i] = 1.0;
        } else {
            outColor[i] = 0.0;
        }
    }
    outColor.a = inColor.a;
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
