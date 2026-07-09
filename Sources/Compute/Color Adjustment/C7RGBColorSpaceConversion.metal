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
        if (*mode < 1.5) {
            outputRGB = half3(
                1.2249401h * r - 0.2249404h * g,
                -0.0420569h * r + 1.0420571h * g,
                -0.0196376h * r - 0.0786361h * g + 1.0982735h * b
            );
        } else if (*mode < 2.5) {
            outputRGB = half3(
                1.3435780h * r - 0.2821790h * g - 0.0613990h * b,
                -0.0652970h * r + 1.0757870h * g - 0.0104900h * b,
                0.0028210h * r - 0.0195980h * g + 1.0167770h * b
            );
        } else if (*mode < 3.5) {
            outputRGB = half3(
                0.7538330h * r + 0.1985970h * g + 0.0475700h * b,
                0.0457440h * r + 0.9417770h * g + 0.0124780h * b,
                -0.0012100h * r + 0.0176010h * g + 0.9836090h * b
            );
        } else if (*mode < 4.5) {
            outputRGB = half3(
                1.6605h * r - 0.5876h * g - 0.0728h * b,
                -0.1246h * r + 1.1329h * g - 0.0083h * b,
                -0.0182h * r - 0.1006h * g + 1.1187h * b
            );
        } else {
            outputRGB = half3(
                0.6274h * r + 0.3293h * g + 0.0433h * b,
                0.0691h * r + 0.9195h * g + 0.0114h * b,
                0.0164h * r + 0.0880h * g + 0.8956h * b
            );
        }
    }

    outputTexture.write(half4(outputRGB, input.a), grid);
}
