//
//  C7WaterRipple.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7WaterRipple(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          constant float *centerX [[buffer(0)]],
                          constant float *centerY [[buffer(1)]],
                          constant float *ripplex [[buffer(2)]],
                          constant float *boundary [[buffer(3)]],
                          uint2 grid [[thread_position_in_grid]]) {
    
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half ripple = half(*ripplex);
    const float2 touchXY = float2(*centerX, *centerY);
    float dis = distance(textureCoordinate, touchXY);
    
    if ((ripple - *boundary) > 0.0 && (dis <= (ripple + *boundary)) && (dis >= (ripple - *boundary))) {
        float moveDis = -pow(8 * (dis - ripple), 3.0);
        float2 unitDirectionVec = normalize(textureCoordinate - touchXY);
        textureCoordinate = textureCoordinate + (unitDirectionVec * moveDis);
    }
    
    float2 clampedCoord = clamp(textureCoordinate, 0.0, 1.0);
    uint2 texCoord = uint2(clampedCoord * float2(inputTexture.get_width(), inputTexture.get_height()));
    const half4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(outColor, grid);
}
