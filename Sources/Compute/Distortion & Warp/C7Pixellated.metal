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
                         constant float4 *harbethRegionContext [[buffer(30)]],
                         uint2 grid [[thread_position_in_grid]]) {

    const float2 logicalSize = max(harbethRegionContext->zw, float2(1.0));
    const float2 globalPixel = float2(grid) + harbethRegionContext->xy;
    const float2 textureCoordinate = globalPixel / logicalSize;
    const float2 scale = float2(*pixelScale, *pixelScale);
    const float2 samplePos = textureCoordinate - fmod(textureCoordinate, scale) + scale * 0.5;
    
    float2 clampedSamplePos = clamp(samplePos, 0.0, 1.0);
    const float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 localSamplePixel = clampedSamplePos * logicalSize - harbethRegionContext->xy;
    uint2 texCoord = uint2(clamp(localSamplePixel, float2(0.0), inputSize - 1.0));
    const half4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(outColor, grid);
}
