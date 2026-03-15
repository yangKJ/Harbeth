//
//  C7MeanBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

// 均值模糊原理其实很简单通过多个纹理叠加，每个纹理偏移量设置不同达到一点重影效果来实现模糊
kernel void C7MeanBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *blurRadius [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const float2 coordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half radius = half(*blurRadius) / 100.0h;
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    // Sample 1: top-left
    float2 coord1 = float2(coordinate.x - radius, coordinate.y - radius);
    uint2 pixel1 = uint2(coord1 * float2(width, height));
    pixel1.x = clamp(pixel1.x, 0u, inputTexture.get_width() - 1u);
    pixel1.y = clamp(pixel1.y, 0u, inputTexture.get_height() - 1u);
    const half4 sample1 = inputTexture.read(pixel1);
    
    // Sample 2: bottom-right
    float2 coord2 = float2(coordinate.x + radius, coordinate.y + radius);
    uint2 pixel2 = uint2(coord2 * float2(width, height));
    pixel2.x = clamp(pixel2.x, 0u, inputTexture.get_width() - 1u);
    pixel2.y = clamp(pixel2.y, 0u, inputTexture.get_height() - 1u);
    const half4 sample2 = inputTexture.read(pixel2);
    
    // Sample 3: top-right
    float2 coord3 = float2(coordinate.x + radius, coordinate.y - radius);
    uint2 pixel3 = uint2(coord3 * float2(width, height));
    pixel3.x = clamp(pixel3.x, 0u, inputTexture.get_width() - 1u);
    pixel3.y = clamp(pixel3.y, 0u, inputTexture.get_height() - 1u);
    const half4 sample3 = inputTexture.read(pixel3);
    
    // Sample 4: bottom-left
    float2 coord4 = float2(coordinate.x - radius, coordinate.y + radius);
    uint2 pixel4 = uint2(coord4 * float2(width, height));
    pixel4.x = clamp(pixel4.x, 0u, inputTexture.get_width() - 1u);
    pixel4.y = clamp(pixel4.y, 0u, inputTexture.get_height() - 1u);
    const half4 sample4 = inputTexture.read(pixel4);
    
    const half4 outColor = (sample1 + sample2 + sample3 + sample4) / 4.0h;
    outputTexture.write(outColor, grid);
}
