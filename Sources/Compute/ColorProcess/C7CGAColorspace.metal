//
//  C7CGAColorspace.metal
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CGAColorspace(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::sample> inputTexture [[texture(1)]],
                            uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 sampleDivisor = float2(1.0 / 200.0, 1.0 / 320.0);
    
    const float2 samplePos = textureCoordinate - fmod(textureCoordinate, sampleDivisor);
    const half4 inColor = inputTexture.sample(quadSampler, samplePos);
    
    const half4 colorCyan = half4(85.0 / 255.0, 1.0, 1.0, 1.0);
    const half4 colorMagenta = half4(1.0, 85.0 / 255.0, 1.0, 1.0);
    const half4 colorWhite = half4(1.0, 1.0, 1.0, 1.0);
    const half4 colorBlack = half4(0.0, 0.0, 0.0, 1.0);
    
    const float blackDistance = distance(inColor, colorBlack);
    const float whiteDistance = distance(inColor, colorWhite);
    const float magentaDistance = distance(inColor, colorMagenta);
    const float cyanDistance = distance(inColor, colorCyan);
    
    float colorDistance = min(magentaDistance, cyanDistance);
    colorDistance = min(colorDistance, whiteDistance);
    colorDistance = min(colorDistance, blackDistance);
    
    half4 outColor;
    if (colorDistance == blackDistance) {
        outColor = colorBlack;
    } else if (colorDistance == whiteDistance) {
        outColor = colorWhite;
    } else if (colorDistance == cyanDistance) {
        outColor = colorCyan;
    } else {
        outColor = colorMagenta;
    }
    
    outputTexture.write(outColor, grid);
}
