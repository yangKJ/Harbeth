//
//  C7ColorPacking.metal
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorPacking(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *texelWidthPointer [[buffer(0)]],
                           constant float *texelHeightPointer [[buffer(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    
    const float texelWidth  = float(*texelWidthPointer / float(width));
    const float texelHeight = float(*texelHeightPointer / float(height));
    
    const float2 textureCoordinate = float2(float(pos.x) / float(width), float(pos.y) / float(height));
    const float2 upperLeftTextureCoordinate = textureCoordinate + float2(-texelWidth, -texelHeight);
    const float2 upperRightTextureCoordinate = textureCoordinate + float2(texelWidth, -texelHeight);
    const float2 lowerLeftTextureCoordinate = textureCoordinate + float2(-texelWidth, texelHeight);
    const float2 lowerRightTextureCoordinate = textureCoordinate + float2(texelWidth, texelHeight);
    
    float2 clampedUpperLeft = clamp(upperLeftTextureCoordinate, float2(0.0), float2(1.0));
    uint2 upperLeftPos = uint2(clampedUpperLeft.x * float(width), clampedUpperLeft.y * float(height));
    upperLeftPos = uint2(clamp(int(upperLeftPos.x), 0, width - 1), clamp(int(upperLeftPos.y), 0, height - 1));
    
    float2 clampedUpperRight = clamp(upperRightTextureCoordinate, float2(0.0), float2(1.0));
    uint2 upperRightPos = uint2(clampedUpperRight.x * float(width), clampedUpperRight.y * float(height));
    upperRightPos = uint2(clamp(int(upperRightPos.x), 0, width - 1), clamp(int(upperRightPos.y), 0, height - 1));
    
    float2 clampedLowerLeft = clamp(lowerLeftTextureCoordinate, float2(0.0), float2(1.0));
    uint2 lowerLeftPos = uint2(clampedLowerLeft.x * float(width), clampedLowerLeft.y * float(height));
    lowerLeftPos = uint2(clamp(int(lowerLeftPos.x), 0, width - 1), clamp(int(lowerLeftPos.y), 0, height - 1));
    
    float2 clampedLowerRight = clamp(lowerRightTextureCoordinate, float2(0.0), float2(1.0));
    uint2 lowerRightPos = uint2(clampedLowerRight.x * float(width), clampedLowerRight.y * float(height));
    lowerRightPos = uint2(clamp(int(lowerRightPos.x), 0, width - 1), clamp(int(lowerRightPos.y), 0, height - 1));
    
    half upperLeftIntensity = inputTexture.read(upperLeftPos).r;
    half upperRightIntensity = inputTexture.read(upperRightPos).r;
    half lowerLeftIntensity = inputTexture.read(lowerLeftPos).r;
    half lowerRightIntensity = inputTexture.read(lowerRightPos).r;
    
    const half4 outColor = half4(upperLeftIntensity, upperRightIntensity, lowerLeftIntensity, lowerRightIntensity);
    
    outputTexture.write(outColor, grid);
}
