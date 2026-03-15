//
//  C7Fluctuate.metal
//  Harbeth
//
//  Created by Condy on 2022/11/30.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Fluctuate(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *frequency [[buffer(0)]],
                        constant float *amplitude [[buffer(1)]],
                        constant float *fluctuate [[buffer(2)]],
                        uint2 grid [[thread_position_in_grid]]) {
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    
    const float2 textureCoordinate = float2(float(pos.x) / float(width), float(pos.y) / float(height));
    
    float2 offset = float2(0, 0);
    offset.x = sin(textureCoordinate.x * *frequency + *fluctuate * 10.0) * *amplitude * *fluctuate;
    offset.y = cos(textureCoordinate.y * *frequency + *fluctuate * 10.0) * *amplitude * *fluctuate;
    
    float2 tx = clamp(textureCoordinate + offset, float2(0.0), float2(1.0));
    uint2 samplePos = uint2(tx.x * float(width), tx.y * float(height));
    
    samplePos = uint2(clamp(int(samplePos.x), 0, width - 1), clamp(int(samplePos.y), 0, height - 1));
    
    const half4 outColor = inputTexture.read(samplePos);
    
    outputTexture.write(outColor, grid);
}
