//
//  C7ColorBurnEnhancedBlend.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorBurnEnhancedBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                     texture2d<half, access::read> blendTexture [[texture(2)]],
                                     constant float *intensity [[buffer(0)]],
                                     constant float *strength [[buffer(1)]],
                                     uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half4 blendColor = blendTexture.read(grid);
    
    half4 outColor;
    
    // Enhanced color burn blend mode
    outColor.r = blendColor.r == 0.0h ? 0.0h : 1.0h - min(1.0h, (1.0h - inColor.r) / (blendColor.r * half(*strength)));
    outColor.g = blendColor.g == 0.0h ? 0.0h : 1.0h - min(1.0h, (1.0h - inColor.g) / (blendColor.g * half(*strength)));
    outColor.b = blendColor.b == 0.0h ? 0.0h : 1.0h - min(1.0h, (1.0h - inColor.b) / (blendColor.b * half(*strength)));
    outColor.a = inColor.a;
    
    // Mix with original color based on intensity
    outColor = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(outColor, grid);
}
