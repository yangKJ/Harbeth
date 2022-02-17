//
//  C7MotionBlur.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7MotionBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::sample> inputTexture [[texture(1)]],
                         constant float *blurSize [[buffer(0)]],
                         constant float *blurAngle [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float pi = 3.14159265358979323846264338327950288;
    
    const float aspectRatio = float(inputTexture.get_height()) / float(inputTexture.get_width());
    float2 directionalTexelStep;
    directionalTexelStep.x = float(*blurSize) * cos(float(*blurAngle) * pi / 180.0) * aspectRatio / inputTexture.get_width();
    directionalTexelStep.y = float(*blurSize) * sin(float(*blurAngle) * pi / 180.0) / inputTexture.get_width();
    
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 oneStepBackTextureCoordinate = textureCoordinate.xy - directionalTexelStep;
    const float2 twoStepsBackTextureCoordinate = textureCoordinate.xy - 2.0 * directionalTexelStep;
    const float2 threeStepsBackTextureCoordinate = textureCoordinate.xy - 3.0 * directionalTexelStep;
    const float2 fourStepsBackTextureCoordinate = textureCoordinate.xy - 4.0 * directionalTexelStep;
    const float2 oneStepForwardTextureCoordinate = textureCoordinate.xy + directionalTexelStep;
    const float2 twoStepsForwardTextureCoordinate = textureCoordinate.xy + 2.0 * directionalTexelStep;
    const float2 threeStepsForwardTextureCoordinate = textureCoordinate.xy + 3.0 * directionalTexelStep;
    const float2 fourStepsForwardTextureCoordinate = textureCoordinate.xy + 4.0 * directionalTexelStep;
    
    half4 outColor = inputTexture.sample(quadSampler, textureCoordinate) * 0.18;
    
    outColor += inputTexture.sample(quadSampler, oneStepBackTextureCoordinate) * 0.15;
    outColor += inputTexture.sample(quadSampler, twoStepsBackTextureCoordinate) *  0.12;
    outColor += inputTexture.sample(quadSampler, threeStepsBackTextureCoordinate) * 0.09;
    outColor += inputTexture.sample(quadSampler, fourStepsBackTextureCoordinate) * 0.05;
    outColor += inputTexture.sample(quadSampler, oneStepForwardTextureCoordinate) * 0.15;
    outColor += inputTexture.sample(quadSampler, twoStepsForwardTextureCoordinate) *  0.12;
    outColor += inputTexture.sample(quadSampler, threeStepsForwardTextureCoordinate) * 0.09;
    outColor += inputTexture.sample(quadSampler, fourStepsForwardTextureCoordinate) * 0.05;
    
    outputTexture.write(outColor, grid);
}

