//
//  C7LuminanceAdaptiveContrast.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LuminanceAdaptiveContrast(texture2d<half, access::write> outputTexture [[texture(0)]],
                                        texture2d<half, access::read> inputTexture [[texture(1)]],
                                        constant float &amount [[buffer(0)]],
                                        constant float &adaptivity [[buffer(1)]],
                                        uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    
    half4 inColor = inputTexture.read(grid);
    
    half luminance = dot(inColor.rgb, half3(0.299h, 0.587h, 0.114h));
    half luminanceFactor = 0.5h - luminance;
    half baseContrast = 1.0h + half(amount) * luminanceFactor * 4.0h;
    
    half finalContrast = mix(1.0h, baseContrast, half(adaptivity));
    half3 adjustedRGB = (inColor.rgb - 0.5h) * finalContrast + 0.5h;
    half4 outColor = half4(clamp(adjustedRGB, 0.0h, 1.0h), inColor.a);
    
    outputTexture.write(outColor, grid);
}
