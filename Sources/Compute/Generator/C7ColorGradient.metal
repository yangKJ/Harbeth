//
//  C7ColorGradient.metal
//  Harbeth
//
//  Created by Condy on 2023/7/27.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7RGUVGradient(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half4 outColor = half4(textureCoordinate.x, textureCoordinate.y, 0, 1);
    
    outputTexture.write(outColor, grid);
}

kernel void C7RGUVB1Gradient(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half4 outColor = half4(textureCoordinate.x, textureCoordinate.y, 1, 1);
    
    outputTexture.write(outColor, grid);
}

kernel void C7RadialGradient(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half4 outColor = half4(half3(1.0 - smoothstep(0.3, 0.8, distance(textureCoordinate, float2(0.5,0.5)))), 1);
    
    outputTexture.write(outColor, grid);
}
