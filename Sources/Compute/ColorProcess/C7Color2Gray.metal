//
//  C7Color2Gray.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Color2Gray(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);
    const half gray = dot(inColor.rgb, kRec709Luma);
    const half4 outColor = half4(half3(gray), 1.0h);
    
    outputTexture.write(outColor, grid);
}
