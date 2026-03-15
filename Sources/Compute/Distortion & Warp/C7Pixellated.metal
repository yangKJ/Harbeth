//
//  C7Pixellated.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Pixellated(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *pixelScale [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 scale = float2(*pixelScale, *pixelScale);
    const float2 samplePos = textureCoordinate - fmod(textureCoordinate, scale) + scale * 0.5;
    
    float2 clampedSamplePos = clamp(samplePos, 0.0, 1.0);
    uint2 texCoord = uint2(clampedSamplePos * float2(inputTexture.get_width(), inputTexture.get_height()));
    const half4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(outColor, grid);
}
