//
//  C7Granularity.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Granularity(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *grain [[buffer(0)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const float d = dot(textureCoordinate, float2(12.9898, 78.233) * 2.0);
    const half noise = half(fract(sin(d) * 43758.5453h));
    const half4 outColor = half4(inColor - noise * (*grain));
    
    outputTexture.write(outColor, grid);
}
