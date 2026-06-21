//
//  C7RGBColorSpaceConversion.metal
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7RGBColorSpaceConversion(texture2d<half, access::write> outputTexture [[texture(0)]],
                                      texture2d<half, access::read> inputTexture [[texture(1)]],
                                      constant float *mode [[buffer(0)]],
                                      uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const half r = input.r;
    const half g = input.g;
    const half b = input.b;

    half3 outputRGB;
    if (*mode < 0.5) {
        outputRGB = half3(
            0.8224621h * r + 0.1775379h * g,
            0.0331941h * r + 0.9668059h * g,
            0.0170827h * r + 0.0723974h * g + 0.9105199h * b
        );
    } else {
        outputRGB = half3(
            1.2249401h * r - 0.2249404h * g,
            -0.0420569h * r + 1.0420571h * g,
            -0.0196376h * r - 0.0786361h * g + 1.0982735h * b
        );
    }

    outputTexture.write(half4(outputRGB, input.a), grid);
}
