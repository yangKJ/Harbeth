//
//  C7BlendPinLight.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7BlendPinLight(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                            constant float *intensity [[buffer(0)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half4 overlay = inputTexture2.sample(quadSampler, textureCoordinate);
    
    half4 outColor;
    
    // Pin Light: 结合了 Darken 和 Lighten
    for (int i = 0; i < 3; i++) {
        if (2.0 * overlay[i] < 1.0) {
            outColor[i] = min(float(inColor[i]), float(2.0 * overlay[i]));
        } else {
            outColor[i] = max(float(inColor[i]), float(2.0 * (overlay[i] - 0.5)));
        }
    }
    outColor.a = inColor.a;
    outColor.rgb = clamp(outColor.rgb, half3(0.0), half3(1.0));
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
