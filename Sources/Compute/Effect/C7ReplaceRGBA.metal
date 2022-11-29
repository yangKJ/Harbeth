//
//  C7ReplaceRGBA.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ReplaceRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *thresholdSensitivity [[buffer(0)]],
                          constant float *smoothing [[buffer(1)]],
                          constant float3 *colorVector [[buffer(2)]],
                          constant float4 *replaceColorVector [[buffer(3)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 color = half3(*colorVector);
    
    const half maskY  = 0.2989h * color.r + 0.5866h * color.g + 0.1145h * color.b;
    const half maskCr = 0.7132h * (color.r - maskY);
    const half maskCb = 0.5647h * (color.b - maskY);
    
    const half Y  = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
    const half Cr = 0.7132h * (inColor.r - Y);
    const half Cb = 0.5647h * (inColor.b - Y);
    
    const half threshold = half(*thresholdSensitivity);
    const half blendValue = smoothstep(threshold, half(threshold + *smoothing), distance(half2(Cr, Cb), half2(maskCr, maskCb)));
    
    half4 outColor = half4(inColor * blendValue);
    if (outColor.a == 0) {
        outColor = half4(*replaceColorVector);
    }
    
    outputTexture.write(outColor, grid);
}
