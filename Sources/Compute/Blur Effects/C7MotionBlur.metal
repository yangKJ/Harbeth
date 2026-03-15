//
//  C7MotionBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7MotionBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *radius [[buffer(0)]],
                         constant float *blurAngle [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const float pi = 3.14159265358979323846264338327950288;
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    const float aspectRatio = height / width;
    float2 directionalTexelStep;
    directionalTexelStep.x = float(*radius) * cos(float(*blurAngle) * pi / 180.0) * aspectRatio / width;
    directionalTexelStep.y = float(*radius) * sin(float(*blurAngle) * pi / 180.0) / width;
    
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 oneStepBackTextureCoordinate = textureCoordinate.xy - directionalTexelStep;
    const float2 twoStepsBackTextureCoordinate = textureCoordinate.xy - 2.0 * directionalTexelStep;
    const float2 threeStepsBackTextureCoordinate = textureCoordinate.xy - 3.0 * directionalTexelStep;
    const float2 fourStepsBackTextureCoordinate = textureCoordinate.xy - 4.0 * directionalTexelStep;
    const float2 oneStepForwardTextureCoordinate = textureCoordinate.xy + directionalTexelStep;
    const float2 twoStepsForwardTextureCoordinate = textureCoordinate.xy + 2.0 * directionalTexelStep;
    const float2 threeStepsForwardTextureCoordinate = textureCoordinate.xy + 3.0 * directionalTexelStep;
    const float2 fourStepsForwardTextureCoordinate = textureCoordinate.xy + 4.0 * directionalTexelStep;
    
    // Direct texture reading with bounds checking
    float2 coord = textureCoordinate * float2(width, height);
    uint2 pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    half4 outColor = inputTexture.read(pixel) * 0.18;
    
    coord = oneStepBackTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.15;
    
    coord = twoStepsBackTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.12;
    
    coord = threeStepsBackTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.09;
    
    coord = fourStepsBackTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.05;
    
    coord = oneStepForwardTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.15;
    
    coord = twoStepsForwardTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.12;
    
    coord = threeStepsForwardTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.09;
    
    coord = fourStepsForwardTextureCoordinate * float2(width, height);
    pixel = uint2(coord.x, coord.y);
    pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
    pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
    outColor += inputTexture.read(pixel) * 0.05;
    
    outputTexture.write(outColor, grid);
}

