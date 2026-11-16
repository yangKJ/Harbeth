//
//  C7EdgeGlow.metal
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7EdgeGlow(texture2d<float, access::write> outputTexture [[texture(0)]],
                       texture2d<float, access::read> inputTexture [[texture(1)]],
                       constant float *timePointer [[buffer(0)]],
                       constant float *spacingPointer [[buffer(1)]],
                       constant float4 *vectorColor [[buffer(2)]],
                       uint2 grid [[thread_position_in_grid]]) {
    
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float2 sourceSize = float2(inputTexture.get_width(), inputTexture.get_height());
    const float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    const bool sameSize = all(sourceSize == outputSize);
    const float2 base = sameSize ? float2(grid) : precise::divide(float2(grid), outputSize) * sourceSize;
    const float4 center = inputTexture.read(uint2(clamp(base, float2(0), sourceSize - 1)));
    const half4 inColor = half4(center);
    const half spacing = half(*spacingPointer);
    
    // 逐邻居求差保持直流稳定；显式平坦标记避免零阈值放大消减舍入。
    float4 result = 0;
    bool hasDifference = false;
    for (int i = 0; i < 9; i++) {
        if (i == 4) continue;
        int a = i % 3; int b = i / 3;
        float2 offset = sameSize ? float2(a - 1, b - 1) : float2(a - 1, b - 1) * precise::divide(sourceSize, outputSize);
        uint2 texCoord = uint2(clamp(base + offset, float2(0), sourceSize - 1));
        const float4 sample = inputTexture.read(texCoord);
        hasDifference = hasDifference || any(center != sample);
        result += center - sample;
    }
    
    if (!hasDifference || length(result) <= spacing) {
        outputTexture.write(center, grid);
        return;
    }
    
    const half time = half(*timePointer);
    const half4 lineColor = half4(*vectorColor);
    const half4 outColor = half4(lineColor * sin(time * 5.0h) + inColor * cos(time * 5.0h));
    
    outputTexture.write(float4(outColor), grid);
}
