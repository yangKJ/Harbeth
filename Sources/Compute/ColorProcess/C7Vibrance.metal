//
//  C7Vibrance.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Vibrance(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *vibrance [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half average = (inColor.r + inColor.g + inColor.b) / 3.0h;
    const half mx = max(inColor.r, max(inColor.g, inColor.b));
    const half amt = (mx - average) * (-half(*vibrance) * 3.0h);
    const half4 outColor = half4(mix(inColor.rgb, half3(mx), amt), inColor.a);
    
    outputTexture.write(outColor, grid);
}
