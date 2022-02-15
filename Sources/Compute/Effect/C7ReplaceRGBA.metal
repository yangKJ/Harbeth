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
                          constant float *colorR [[buffer(2)]],
                          constant float *colorG [[buffer(3)]],
                          constant float *colorB [[buffer(4)]],
                          constant float *replaceColorR [[buffer(5)]],
                          constant float *replaceColorG [[buffer(6)]],
                          constant float *replaceColorB [[buffer(7)]],
                          constant float *replaceColorA [[buffer(8)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half R = half(*colorR);
    const half G = half(*colorG);
    const half B = half(*colorB);
    
    const half maskY = 0.2989h * R + 0.5866h * G + 0.1145h * B;
    const half maskCr = 0.7132h * (R - maskY);
    const half maskCb = 0.5647h * (B - maskY);
    
    const half Y = 0.2989h * inColor.r + 0.5866h * inColor.g + 0.1145h * inColor.b;
    const half Cr = 0.7132h * (inColor.r - Y);
    const half Cb = 0.5647h * (inColor.b - Y);
    
    const half blendValue = smoothstep(half(*thresholdSensitivity), half(*thresholdSensitivity + *smoothing), distance(half2(Cr, Cb), half2(maskCr, maskCb)));
    
    half4 outColor(inColor * blendValue);
    if (outColor.a == 0) {
        outColor = half4(*replaceColorR, *replaceColorG, *replaceColorB, *replaceColorA);
    }
    
    outputTexture.write(outColor, grid);
}


