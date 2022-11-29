//
//  C7ColorPacking.metal
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorPacking(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::sample> inputTexture [[texture(1)]],
                           device float *texelWidthPointer [[buffer(0)]],
                           device float *texelHeightPointer [[buffer(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float width  = outputTexture.get_width();
    const float height = outputTexture.get_height();
    const float texelWidth  = float(*texelWidthPointer / width);
    const float texelHeight = float(*texelHeightPointer / height);
    
    const float2 textureCoordinate = float2(float(grid.x) / width, float(grid.y) / height);
    const float2 upperLeftTextureCoordinate = textureCoordinate + float2(-texelWidth, -texelHeight);
    const float2 upperRightTextureCoordinate = textureCoordinate + float2(texelWidth, -texelHeight);
    const float2 lowerLeftTextureCoordinate = textureCoordinate + float2(-texelWidth, texelHeight);
    const float2 lowerRightTextureCoordinate = textureCoordinate + float2(texelWidth, texelHeight);
    
    half upperLeftIntensity = inputTexture.sample(quadSampler, upperLeftTextureCoordinate).r;
    half upperRightIntensity = inputTexture.sample(quadSampler, upperRightTextureCoordinate).r;
    half lowerLeftIntensity = inputTexture.sample(quadSampler, lowerLeftTextureCoordinate).r;
    half lowerRightIntensity = inputTexture.sample(quadSampler, lowerRightTextureCoordinate).r;
    
    const half4 outColor = half4(upperLeftIntensity, upperRightIntensity, lowerLeftIntensity, lowerRightIntensity);
    
    outputTexture.write(outColor, grid);
}
