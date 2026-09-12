//
//  C7Sketch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

inline uint2 sketchClampedCoordinate(int2 coordinate, uint width, uint height) {
    return uint2(clamp(coordinate, int2(0), int2(int(width) - 1, int(height) - 1)));
}

kernel void C7Sketch(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float *edgeStrength [[buffer(0)]],
                     uint2 grid [[thread_position_in_grid]]) {
    const int sobelStep = 2;
    const half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);
    const int2 center = int2(grid);
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();

    const half4 topLeft = inputTexture.read(sketchClampedCoordinate(center + int2(-sobelStep, -sobelStep), width, height));
    const half4 top = inputTexture.read(sketchClampedCoordinate(center + int2(0, -sobelStep), width, height));
    const half4 topRight = inputTexture.read(sketchClampedCoordinate(center + int2(sobelStep, -sobelStep), width, height));
    const half4 centerLeft = inputTexture.read(sketchClampedCoordinate(center + int2(-sobelStep, 0), width, height));
    const half4 centerRight = inputTexture.read(sketchClampedCoordinate(center + int2(sobelStep, 0), width, height));
    const half4 bottomLeft = inputTexture.read(sketchClampedCoordinate(center + int2(-sobelStep, sobelStep), width, height));
    const half4 bottom = inputTexture.read(sketchClampedCoordinate(center + int2(0, sobelStep), width, height));
    const half4 bottomRight = inputTexture.read(sketchClampedCoordinate(center + int2(sobelStep, sobelStep), width, height));
    
    const half4 h = -topLeft - 2.0h * top - topRight + bottomLeft + 2.0h * bottom + bottomRight;
    const half4 v = -bottom - 2.0h * centerLeft - topLeft + bottomRight + 2.0h * centerRight + topRight;
    
    half grayH = dot(h.rgb, kRec709Luma);
    half grayV = dot(v.rgb, kRec709Luma);
    
    // sqrt(h^2 + v^2), 求点到(h, v)的距离
    half color = length(half2(grayH, grayV)) * (*edgeStrength);
    const half4 outColor = half4(half3(1.0h - color), 1.0h);
    outputTexture.write(outColor, grid);
}
