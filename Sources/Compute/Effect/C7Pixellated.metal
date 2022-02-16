//
//  C7Pixellated.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Pixellated(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::sample> inputTexture [[texture(1)]],
                         constant float *pixelWidth [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float inputw = float(inputTexture.get_width());
    const float inputh = float(inputTexture.get_height());
    const float2 sampleDivisor = float2(float(*pixelWidth), float(*pixelWidth) * inputw / inputh);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 xxx = textureCoordinate - sampleDivisor * floor(textureCoordinate / sampleDivisor);
    const float2 samplePos = textureCoordinate - xxx + float2(0.5) * sampleDivisor;
    const half4 outColor = inputTexture.sample(quadSampler, samplePos);
    
    outputTexture.write(outColor, grid);
}
