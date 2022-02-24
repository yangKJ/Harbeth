//
//  C7ColorRGBA.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *red [[buffer(0)]],
                        constant float *green [[buffer(1)]],
                        constant float *blue [[buffer(2)]],
                        constant float *alpha [[buffer(3)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(inColor.r * half(*red), inColor.g * half(*green), inColor.b * half(*blue), inColor.a * half(*alpha));
    
    outputTexture.write(outColor, grid);
}
