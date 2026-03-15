//
//  C7ConvolutionMatrix3x3.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ConvolutionMatrix3x3(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   constant float *intensity [[buffer(0)]],
                                   constant float *pixel [[buffer(1)]],
                                   constant float3x3 *matrix3x3 [[buffer(2)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float w = float(inputTexture.get_width());
    const float h = float(inputTexture.get_height());
    const float l = float(x - *pixel);
    const float r = float(x + *pixel);
    const float t = float(y - *pixel);
    const float b = float(y + *pixel);
    
    // Normalization and clamping
    float2 m11Coordinate = float2(l / w, t / h);
    float2 m12Coordinate = float2(x / w, t / h);
    float2 m13Coordinate = float2(r / w, t / h);
    float2 m21Coordinate = float2(l / w, y / h);
    float2 m22Coordinate = float2(x / w, y / h);
    float2 m23Coordinate = float2(r / w, y / h);
    float2 m31Coordinate = float2(l / w, b / h);
    float2 m32Coordinate = float2(x / w, b / h);
    float2 m33Coordinate = float2(r / w, b / h);
    
    // Clamp coordinates to [0, 1]
    m11Coordinate = clamp(m11Coordinate, 0.0, 1.0);
    m12Coordinate = clamp(m12Coordinate, 0.0, 1.0);
    m13Coordinate = clamp(m13Coordinate, 0.0, 1.0);
    m21Coordinate = clamp(m21Coordinate, 0.0, 1.0);
    m22Coordinate = clamp(m22Coordinate, 0.0, 1.0);
    m23Coordinate = clamp(m23Coordinate, 0.0, 1.0);
    m31Coordinate = clamp(m31Coordinate, 0.0, 1.0);
    m32Coordinate = clamp(m32Coordinate, 0.0, 1.0);
    m33Coordinate = clamp(m33Coordinate, 0.0, 1.0);
    
    // Convert to texture coordinates
    uint2 m11Coord = uint2(m11Coordinate * float2(w, h));
    uint2 m12Coord = uint2(m12Coordinate * float2(w, h));
    uint2 m13Coord = uint2(m13Coordinate * float2(w, h));
    uint2 m21Coord = uint2(m21Coordinate * float2(w, h));
    uint2 m22Coord = uint2(m22Coordinate * float2(w, h));
    uint2 m23Coord = uint2(m23Coordinate * float2(w, h));
    uint2 m31Coord = uint2(m31Coordinate * float2(w, h));
    uint2 m32Coord = uint2(m32Coordinate * float2(w, h));
    uint2 m33Coord = uint2(m33Coordinate * float2(w, h));
    
    const half4 centerColor = inputTexture.read(m22Coord);
    
    const half3 m11Color = inputTexture.read(m11Coord).rgb;
    const half3 m12Color = inputTexture.read(m12Coord).rgb;
    const half3 m13Color = inputTexture.read(m13Coord).rgb;
    const half3 m21Color = inputTexture.read(m21Coord).rgb;
    const half3 m22Color = centerColor.rgb;
    const half3 m23Color = inputTexture.read(m23Coord).rgb;
    const half3 m31Color = inputTexture.read(m31Coord).rgb;
    const half3 m32Color = inputTexture.read(m32Coord).rgb;
    const half3 m33Color = inputTexture.read(m33Coord).rgb;
    
    const float3x3 matrix = (*matrix3x3);
    half3 resultColor = half3(0.0h);
    resultColor += m11Color * (matrix[0][0]) + m12Color * (matrix[0][1]) + m13Color * (matrix[0][2]);
    resultColor += m21Color * (matrix[1][0]) + m22Color * (matrix[1][1]) + m23Color * (matrix[1][2]);
    resultColor += m31Color * (matrix[2][0]) + m32Color * (matrix[2][1]) + m33Color * (matrix[2][2]);
    
    const half4 outColor = half4(resultColor, centerColor.a);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
