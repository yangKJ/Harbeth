//
//  C7ConvolutionMatrix3x3.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ConvolutionMatrix3x3(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::sample> inputTexture [[texture(1)]],
                                   constant float *pixel [[buffer(0)]],
                                   constant float3x3 *matrix3x3 [[buffer(1)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float w = float(inputTexture.get_width());
    const float h = float(inputTexture.get_height());
    const float l = float(x - *pixel);
    const float r = float(x + *pixel);
    const float t = float(y - *pixel);
    const float b = float(y + *pixel);
    
    // Normalization
    const float2 m11Coordinate = float2(l / w, t / h);
    const float2 m12Coordinate = float2(x / w, t / h);
    const float2 m13Coordinate = float2(r / w, t / h);
    const float2 m21Coordinate = float2(l / w, y / h);
    const float2 m22Coordinate = float2(x / w, y / h);
    const float2 m23Coordinate = float2(r / w, y / h);
    const float2 m31Coordinate = float2(l / w, b / h);
    const float2 m32Coordinate = float2(x / w, b / h);
    const float2 m33Coordinate = float2(r / w, b / h);
    
    const half4 centerColor = inputTexture.sample(quadSampler, m22Coordinate);
    
    const half3 m11Color = inputTexture.sample(quadSampler, m11Coordinate).rgb;
    const half3 m12Color = inputTexture.sample(quadSampler, m12Coordinate).rgb;
    const half3 m13Color = inputTexture.sample(quadSampler, m13Coordinate).rgb;
    const half3 m21Color = inputTexture.sample(quadSampler, m21Coordinate).rgb;
    const half3 m22Color = centerColor.rgb;
    const half3 m23Color = inputTexture.sample(quadSampler, m23Coordinate).rgb;
    const half3 m31Color = inputTexture.sample(quadSampler, m31Coordinate).rgb;
    const half3 m32Color = inputTexture.sample(quadSampler, m32Coordinate).rgb;
    const half3 m33Color = inputTexture.sample(quadSampler, m33Coordinate).rgb;
    
    const float3x3 matrix = (*matrix3x3);
    half3 resultColor = half3(0.0h);
    resultColor += m11Color * (matrix[0][0]) + m12Color * (matrix[0][1]) + m13Color * (matrix[0][2]);
    resultColor += m21Color * (matrix[1][0]) + m22Color * (matrix[1][1]) + m23Color * (matrix[1][2]);
    resultColor += m31Color * (matrix[2][0]) + m32Color * (matrix[2][1]) + m33Color * (matrix[2][2]);
    
    const half4 outColor = half4(resultColor, centerColor.a);
    outputTexture.write(outColor, grid);
}
