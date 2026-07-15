//
//  C7SoulOut.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SoulOut(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      constant float *soulPointer [[buffer(0)]],
                      constant float *maxScalePointer [[buffer(1)]],
                      constant float *maxAlphaPointer [[buffer(2)]],
                      constant float4 *regionContext [[buffer(30)]],
                      uint2 grid [[thread_position_in_grid]]) {
    const int2 inputSize = int2(inputTexture.get_width(), inputTexture.get_height());
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float2 globalPixel = float2(grid) + outputRegion.xy;
    const float x = globalPixel.x / outputRegion.z;
    const float y = globalPixel.y / outputRegion.w;
    const half4 inColor = inputTexture.read(grid);
    
    const half soul = half(*soulPointer);
    const half maxScale = half(*maxScalePointer);
    const half maxAlpha = half(*maxAlphaPointer);
    
    const half alpha = maxAlpha * (1.0h - soul);
    const half scale = 1.0h + (maxScale - 1.0h) * soul;
    
    const half soulX = 0.5h + (x - 0.5h) / scale;
    const half soulY = 0.5h + (y - 0.5h) / scale;
    
    float2 soulCoord = float2(soulX, soulY);
    soulCoord = clamp(soulCoord, float2(0.0), float2(1.0));
    const float2 soulGlobalPixel = soulCoord * inputRegion.zw;
    const int2 soulPos = clamp(int2(soulGlobalPixel - inputRegion.xy), int2(0), inputSize - 1);
    
    // 最终色 = 基色 * (1 - a) + 混合色 * a
    const half4 soulMask = inputTexture.read(uint2(soulPos));
    const half4 outColor = inColor * (1.0h - alpha) + soulMask * alpha;
    
    outputTexture.write(outColor, grid);
}
