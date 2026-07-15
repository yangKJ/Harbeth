//
//  C7Glitch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Glitch(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float *progressPointer [[buffer(0)]],
                     constant float *maxJitterPointer [[buffer(1)]],
                     constant float4 *harbethRegionContext [[buffer(30)]],
                     uint2 grid [[thread_position_in_grid]]) {
    const float2 logicalSize = max(harbethRegionContext->zw, float2(1.0));
    const float2 globalPixel = float2(grid) + harbethRegionContext->xy;
    const float2 textureCoordinate = globalPixel / logicalSize;
    const half4 inColor = inputTexture.read(grid);
    const float x = textureCoordinate.x;
    const float y = textureCoordinate.y;
    
    const half progress = half(*progressPointer) * 2.0h;
    const half maxJitter = half(*maxJitterPointer);
    
    const half colorROffset = 0.01h;
    const half colorBOffset = -0.025h;
    const float PI = 3.14159265358979323846264338327950288;
    const float amplitude = max(sin(PI / progress), 0.0);
    const float jitter = fract(sin(y) * 43758.5453123) * 2.0 - 1.0;
    const bool needOffset = abs(jitter) < maxJitter * amplitude;
    const float textureX = x + (needOffset ? jitter : (jitter * amplitude * 0.006));
    const float2 textureCoords = float2(textureX, y);
    
    float2 maskRCoord = clamp(textureCoords + float2(colorROffset * amplitude, 0.0), 0.0, 1.0);
    float2 maskBCoord = clamp(textureCoords + float2(colorBOffset * amplitude, 0.0), 0.0, 1.0);
    const float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 maskRLocalPixel = maskRCoord * logicalSize - harbethRegionContext->xy;
    float2 maskBLocalPixel = maskBCoord * logicalSize - harbethRegionContext->xy;
    uint2 maskRTexCoord = uint2(clamp(maskRLocalPixel, float2(0.0), inputSize - 1.0));
    uint2 maskBTexCoord = uint2(clamp(maskBLocalPixel, float2(0.0), inputSize - 1.0));
    const half4 maskR = inputTexture.read(maskRTexCoord);
    const half4 maskB = inputTexture.read(maskBTexCoord);
    const half4 outColor = half4(maskR.r, inColor.g, maskB.b, inColor.a);
    
    outputTexture.write(outColor, grid);
}
