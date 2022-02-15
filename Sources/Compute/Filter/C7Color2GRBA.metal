//
//  C7Color2GRBA.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Color2GRBA(texture2d<half, access::write> outTexture [[texture(0)]],
                         texture2d<half, access::read> inTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    
    const half4 outColor(inColor.grb, inColor.a);
    
    outTexture.write(outColor, grid);
}
