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
                          constant float4 *regionContext [[buffer(30)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float2 globalPixel = float2(grid) + outputRegion.xy;
    float2 textureCoordinate = globalPixel / max(outputRegion.zw, float2(1.0));
    const half ripple = half(*ripplex);
    const float2 touchXY = float2(*centerX, *centerY);
    float dis = distance(textureCoordinate, touchXY);
    
    if ((ripple - *boundary) > 0.0 && (dis <= (ripple + *boundary)) && (dis >= (ripple - *boundary))) {
        float moveDis = -pow(8 * (dis - ripple), 3.0);
        float2 unitDirectionVec = normalize(textureCoordinate - touchXY);
        textureCoordinate = textureCoordinate + (unitDirectionVec * moveDis);
    }
    
    float2 clampedCoord = clamp(textureCoordinate, 0.0, 1.0);
    const float2 localPixel = clampedCoord * inputRegion.zw - inputRegion.xy;
    const int2 safeCoord = clamp(int2(localPixel), int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
    const half4 outColor = inputTexture.read(uint2(safeCoord));
    
    outputTexture.write(outColor, grid);
}
