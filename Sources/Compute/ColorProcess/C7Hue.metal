//
//  C7Hue.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

#include <metal_stdlib>
using namespace metal;

constant half4 kRGBToYPrime = half4(0.299, 0.587, 0.114, 0.0);
constant half4 kRGBToI = half4(0.595716, -0.274453, -0.321263, 0.0);
constant half4 kRGBToQ = half4(0.211456, -0.522591, 0.31135, 0.0);
constant half4 kYIQToR = half4(1.0, 0.9563, 0.6210, 0.0);
constant half4 kYIQToG = half4(1.0, -0.2721, -0.6474, 0.0);
constant half4 kYIQToB = half4(1.0, -1.1070, 1.7046, 0.0);

kernel void C7Hue(texture2d<half, access::write> outputTexture [[texture(0)]],
                  texture2d<half, access::read> inputTexture [[texture(1)]],
                  device float *hueAdjust [[buffer(0)]],
                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    // Convert to YIQ
    const half YPrime = dot(inColor, kRGBToYPrime);
    half I = dot(inColor, kRGBToI);
    half Q = dot(inColor, kRGBToQ);
    
    // Calculate the hue and chroma
    half hue = atan2(Q, I);
    const half chroma = sqrt(I * I + Q * Q);
    
    // Make the user's adjustments
    hue += (- *hueAdjust);
    
    // Convert back to YIQ
    Q = chroma * sin(hue);
    I = chroma * cos(hue);
    
    // Convert back to RGB
    const half4 yIQ = half4(YPrime, I, Q, 0.0h);
    const half4 outColor = half4(dot(yIQ, kYIQToR), dot(yIQ, kYIQToG), dot(yIQ, kYIQToB), inColor.a);
    
    outputTexture.write(outColor, grid);
}
