//
//  C7AppleLogDecode.metal
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7AppleLogDecode(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    half4 linearColor;
    half3 logColor = inColor.rgb;
    
    half3 linearRGB = pow(2.0h, (logColor - 0.5h) * 12.0h) - 0.0001h;
    linearRGB = max(linearRGB, half3(0.0h));
    
    linearColor.rgb = linearRGB;
    linearColor.a = inColor.a;
    
    outputTexture.write(linearColor, grid);
}
