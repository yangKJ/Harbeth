//
//  C7Exposure.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Exposure(texture2d<half, access::write> outTexture [[texture(0)]],
                       texture2d<half, access::read> inTexture [[texture(1)]],
                       device float *exposure [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inTexture.read(grid);
    
    const half4 outColor((inColor.rgb * pow(2.0, *exposure)), inColor.a);
    
    outTexture.write(outColor, grid);
}
