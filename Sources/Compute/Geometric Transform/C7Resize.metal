//
//  C7Resize.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Resize(texture2d<float, access::write> outputTexture [[texture(0)]],
                     texture2d<float, access::read> inputTexture [[texture(1)]],
                     constant float &halfOutput [[buffer(0)]],
                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    if (outputTexture.get_width() == inputTexture.get_width() && outputTexture.get_height() == inputTexture.get_height()) {
        const float4 value = inputTexture.read(grid);
        outputTexture.write(halfOutput > 0.5f ? float4(half4(value)) : value, grid); return;
    }
    float2 sampleCoord = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    sampleCoord = clamp(sampleCoord, 0.0, 1.0);
    uint2 texCoord = uint2(sampleCoord * float2(inputTexture.get_width(), inputTexture.get_height()));
    const float4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(halfOutput > 0.5f ? float4(half4(outColor)) : outColor, grid);
}
