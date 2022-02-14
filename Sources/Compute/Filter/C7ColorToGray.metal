//
//  C7ColorToGray.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorToGray(texture2d<half, access::write> outTexture [[texture(0)]],
                          texture2d<half, access::read> inTexture [[texture(1)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    
    const half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);
    half  gray = dot(inColor.rgb, kRec709Luma);
    const half4 outColor(half4(gray, gray, gray, 1.0));
    
    outTexture.write(outColor, grid);
}
