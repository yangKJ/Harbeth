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
    half4 color = inputTexture.read(grid);
    
    const half average = (color.r + color.g + color.b) / 3.0;
    const half mx = max(color.r, max(color.g, color.b));
    const half amt = (mx - average) * (-half(*vibrance) * 3.0);
    color.rgb = mix(color.rgb, half3(mx), amt);
    
    outputTexture.write(color, grid);
}
