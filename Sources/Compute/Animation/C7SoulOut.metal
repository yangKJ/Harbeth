//
//  C7SoulOut.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SoulOut(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::sample> inputTexture [[texture(1)]],
                      constant float *soulPointer [[buffer(0)]],
                      constant float *maxScalePointer [[buffer(1)]],
                      constant float *maxAlphaPointer [[buffer(2)]],
                      uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half soul = half(*soulPointer);
    const half maxScale = half(*maxScalePointer);
    const half maxAlpha = half(*maxAlphaPointer);
    
    const half alpha = maxAlpha * (1.0h - soul);
    const half scale = 1.0h + (maxScale - 1.0h) * soul;
    
    const half weakX = 0.5h + (textureCoordinate.x - 0.5h) / scale;
    const half weakY = 0.5h + (textureCoordinate.y - 0.5h) / scale;
    
    const float2 weakTextureCoords = float2(weakX, weakY);
    const half4 weakMask = inputTexture.sample(quadSampler, weakTextureCoords);
    const half4 mask = inputTexture.sample(quadSampler, textureCoordinate);
    
    // 最终色 = 混合色 * (1 - a%) + 基色 * a%
    const half4 outColor = mask * (1.0h - alpha) + weakMask * alpha;
    
    outputTexture.write(outColor, grid);
}
