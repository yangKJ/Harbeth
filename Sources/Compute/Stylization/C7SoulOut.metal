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
                      uint2 grid [[thread_position_in_grid]]) {
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    
    const half4 inColor = inputTexture.read(pos);
    const float x = float(pos.x) / float(width);
    const float y = float(pos.y) / float(height);
    
    const half soul = half(*soulPointer);
    const half maxScale = half(*maxScalePointer);
    const half maxAlpha = half(*maxAlphaPointer);
    
    const half alpha = maxAlpha * (1.0h - soul);
    const half scale = 1.0h + (maxScale - 1.0h) * soul;
    
    const half soulX = 0.5h + (x - 0.5h) / scale;
    const half soulY = 0.5h + (y - 0.5h) / scale;
    
    float2 soulCoord = float2(soulX, soulY);
    soulCoord = clamp(soulCoord, float2(0.0), float2(1.0));
    uint2 soulPos = uint2(soulCoord.x * float(width), soulCoord.y * float(height));
    soulPos = uint2(clamp(int(soulPos.x), 0, width - 1), clamp(int(soulPos.y), 0, height - 1));
    
    // 最终色 = 基色 * (1 - a) + 混合色 * a
    const half4 soulMask = inputTexture.read(soulPos);
    const half4 outColor = inColor * (1.0h - alpha) + soulMask * alpha;
    
    outputTexture.write(outColor, grid);
}
