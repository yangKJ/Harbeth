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
    const half4 inColor = inputTexture.read(grid);
    const float x = float(grid.x) / outputTexture.get_width();
    const float y = float(grid.y) / outputTexture.get_height();
    
    const half soul = half(*soulPointer);
    const half maxScale = half(*maxScalePointer);
    const half maxAlpha = half(*maxAlphaPointer);
    
    const half alpha = maxAlpha * (1.0h - soul);
    const half scale = 1.0h + (maxScale - 1.0h) * soul;
    
    const half soulX = 0.5h + (x - 0.5h) / scale;
    const half soulY = 0.5h + (y - 0.5h) / scale;
    
    // 最终色 = 基色 * (1 - a) + 混合色 * a
    const half4 soulMask = inputTexture.sample(quadSampler, float2(soulX, soulY));
    const half4 outColor = inColor * (1.0h - alpha) + soulMask * alpha;
    
    outputTexture.write(outColor, grid);
}
