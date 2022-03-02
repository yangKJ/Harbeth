//
//  C7Sobel.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Sobel(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *edgeStrength [[buffer(0)]],
                    uint2 grid [[thread_position_in_grid]]) {
    const half sobelStep = half(2.0h);
    const half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);
    
    const half4 topLeft     = inputTexture.read(uint2(grid.x - sobelStep, grid.y - sobelStep));
    const half4 top         = inputTexture.read(uint2(grid.x, grid.y - sobelStep));
    const half4 topRight    = inputTexture.read(uint2(grid.x + sobelStep, grid.y - sobelStep));
    const half4 centerLeft  = inputTexture.read(uint2(grid.x - sobelStep, grid.y));
    const half4 centerRight = inputTexture.read(uint2(grid.x + sobelStep, grid.y));
    const half4 bottomLeft  = inputTexture.read(uint2(grid.x - sobelStep, grid.y + sobelStep));
    const half4 bottom      = inputTexture.read(uint2(grid.x, grid.y + sobelStep));
    const half4 bottomRight = inputTexture.read(uint2(grid.x + sobelStep, grid.y + sobelStep));
    
    const half4 h = -topLeft - 2.0h * top - topRight + bottomLeft + 2.0h * bottom + bottomRight;
    const half4 v = -bottom - 2.0h * centerLeft - topLeft + bottomRight + 2.0h * centerRight + topRight;
    
    half grayH = dot(h.rgb, kRec709Luma);
    half grayV = dot(v.rgb, kRec709Luma);
    
    // sqrt(h^2 + v^2), 求点到(h, v)的距离
    half color = length(half2(grayH, grayV)) * (*edgeStrength);
    const half4 outColor = half4(half3(color), 1.0h);
    
    outputTexture.write(outColor, grid);
}
