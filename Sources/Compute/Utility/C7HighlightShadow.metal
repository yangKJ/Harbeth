//
//  C7HighlightShadow.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7HighlightShadow(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *shadows [[buffer(0)]],
                              constant float *highlights [[buffer(1)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    // Clamp luminance for pow() stability, but preserve HDR via the ratio (inColor / luminance).
    const half lumSDR = clamp(luminance, 0.001h, 1.0h);
    // Shadow adjustment must be non-negative (only lifts), highlight must be non-positive (only pulls down).
    // These clamps constrain adjustment direction, not color output.
    const half shadow = clamp((pow(lumSDR, 1.0h / (half(*shadows) + 1.0h)) + (-0.76h) * pow(lumSDR, 2.0h / (half(*shadows) + 1.0h))) - lumSDR, 0.0h, 1.0h);
    const half highlight = clamp((1.0h - (pow(1.0h - lumSDR, 1.0h / (2.0h - half(*highlights))) + (-0.8h) * pow(1.0h - lumSDR, 2.0h / (2.0h - half(*highlights))))) - lumSDR, -1.0h, 0.0h);
    // Scale original color proportionally — preserves HDR headroom via inColor/lumSDR ratio.
    const half3 result = (lumSDR + shadow + highlight) * (inColor.rgb / lumSDR);
    const half4 outColor = half4(result.rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
