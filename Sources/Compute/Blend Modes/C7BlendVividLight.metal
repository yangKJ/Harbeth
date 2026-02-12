//
//  C7BlendVividLight.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendVividLight(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                              constant float *intensity [[buffer(0)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    
    // Vivid Light: 结合了 Color Burn 和 Color Dodge
    for (int i = 0; i < 3; i++) {
        if (overlay[i] < 0.5) {
            outColor[i] = 1.0 - (1.0 - inColor[i]) / (2.0 * overlay[i] + 0.001);
        } else {
            outColor[i] = inColor[i] / (1.0 - 2.0 * (overlay[i] - 0.5) + 0.001);
        }
    }
    outColor.a = inColor.a;
    outColor.rgb = clamp(outColor.rgb, half3(0.0), half3(1.0));
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
