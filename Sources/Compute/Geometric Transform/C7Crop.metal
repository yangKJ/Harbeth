//
//  C7Crop.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Crop(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::read> inputTexture [[texture(1)]],
                   constant float *originX [[buffer(0)]],
                   constant float *originY [[buffer(1)]],
                   uint2 grid [[thread_position_in_grid]]) {
    
    const float minX = inputTexture.get_width()  * (*originX);
    const float minY = inputTexture.get_height() * (*originY);
    
    float2 sampleCoord = float2((grid.x + minX) / inputTexture.get_width(), (grid.y + minY) / inputTexture.get_height());
    sampleCoord = clamp(sampleCoord, 0.0, 1.0);
    uint2 texCoord = uint2(sampleCoord * float2(inputTexture.get_width(), inputTexture.get_height()));
    const half4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(outColor, grid);
}
