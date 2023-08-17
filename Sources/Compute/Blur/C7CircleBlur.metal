//
//  C7CircleBlur.metal
//  Harbeth
//
//  Created by Condy on 2023/8/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CircleBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::sample> inputTexture [[texture(1)]],
                         constant float *blurRadius [[buffer(0)]],
                         constant float *sampleCountPointer [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 textureCoordinate = float2(grid) / float2(outputTexture.get_width(), outputTexture.get_height());
    const half radius = half(*blurRadius) / 100.0h;
    const half sampleCount = half(*sampleCountPointer);
    
    half4 result = half4(0.0h);
    for (int i = 0; i < sampleCount; ++i) {
        float fraction = float(i) / sampleCount;
        float x = textureCoordinate.x;
        float y = textureCoordinate.y;
        float angle = fraction * M_PI_F * 2;
        x += cos(angle) * radius;
        y += sin(angle) * radius;
        const half4 sample = inputTexture.sample(quadSampler, float2(x, y));
        result += sample;
    }
    
    const half4 outColor = result / sampleCount;
    outputTexture.write(outColor, grid);
}
