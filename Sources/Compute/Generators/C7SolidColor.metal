//
//  C7SolidColor.metal
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

#include <metal_stdlib>
using namespace metal;

// Bytes are being bound at index 0 to a shader argument with write access enabled.'
// If use `device` and then throw the error as above.
// See: https://developer.apple.com/forums/thread/658233

kernel void C7SolidColor(texture2d<float, access::write> outputTexture [[texture(0)]],
                         texture2d<float, access::read> inputTexture [[texture(1)]],
                         constant float4 *colorVector [[buffer(0)]],
                         constant float &halfOutput [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 outColor = *colorVector;
    
    outputTexture.write(halfOutput > 0.5f ? float4(half4(outColor)) : outColor, grid);
}
