//
//  C7EdgeGlow.metal
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7EdgeGlow(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::sample> inputTexture [[texture(1)]],
                       constant float *timePointer [[buffer(0)]],
                       constant float *lineR [[buffer(1)]],
                       constant float *lineG [[buffer(2)]],
                       constant float *lineB [[buffer(3)]],
                       constant float *lineA [[buffer(4)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    float w = outputTexture.get_width();
    float h = outputTexture.get_height();
    const float2 textureCoordinate = float2(grid) / float2(w, h);
    const half time = half(*timePointer);
    const int kernelWidth = 3;
    const int kernelHeight = 3;
    const half4 lineColor = half4(*lineR, *lineG, *lineB, *lineA);
    
    float k[9];
    k[0] = -1.0; k[1] = -1.0; k[2] = -1.0;
    k[3] = -1.0; k[4] =  8.0; k[5] = -1.0;
    k[6] = -1.0; k[7] = -1.0; k[8] = -1.0;
    
    half4 result = half4(0.0h);
    for (int y = 0; y < kernelHeight; ++y) {
        for (int x = 0; x < kernelWidth; ++x) {
            float2 position = float2(textureCoordinate.x + float(x - kernelWidth / 2.0) / w,
                                     textureCoordinate.y + float(y - kernelHeight / 2.0) / h);
            const half4 rgba = inputTexture.read(uint2(position * float2(w, h)));
            result += rgba * k[x + y * kernelWidth];
        }
    }
    
    if (length(result) <= 0.2) {
        outputTexture.write(inColor, grid);
    } else {
        const half4 outColor = half4(lineColor * sin(time * 5.0h) + inColor * cos(time * 5.0h));
        outputTexture.write(outColor, grid);
    }
}
