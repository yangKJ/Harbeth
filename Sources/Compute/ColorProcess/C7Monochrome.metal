//
//  C7Monochrome.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Monochrome(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *intensity [[buffer(0)]],
                         constant float *colorR [[buffer(1)]],
                         constant float *colorG [[buffer(2)]],
                         constant float *colorB [[buffer(3)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    const half4 desat = half4(half3(luminance), 1.0h);
    const half r = desat.r < 0.5 ? (2.0 * desat.r * half(*colorR)) : (1.0 - 2.0 * (1.0 - desat.r) * (1.0 - half(*colorR)));
    const half g = desat.g < 0.5 ? (2.0 * desat.g * half(*colorG)) : (1.0 - 2.0 * (1.0 - desat.g) * (1.0 - half(*colorG)));
    const half b = desat.b < 0.5 ? (2.0 * desat.b * half(*colorB)) : (1.0 - 2.0 * (1.0 - desat.b) * (1.0 - half(*colorB)));
    const half4 outColor = half4(mix(inColor.rgb, half3(r, g, b), half(*intensity)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
