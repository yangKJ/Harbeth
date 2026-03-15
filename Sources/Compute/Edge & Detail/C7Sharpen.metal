//
//  C7Sharpen.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Sharpen(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      constant float *sharpeness [[buffer(0)]],
                      uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    float2 leftCoordinate = float2((x - 1) / width, y / height);
    float2 rightCoordinate = float2((x + 1) / width, y / height);
    float2 topCoordinate = float2(x / width, (y - 1) / height);
    float2 bottomCoordinate = float2(x / width, (y + 1) / height);
    
    leftCoordinate = clamp(leftCoordinate, 0.0, 1.0);
    rightCoordinate = clamp(rightCoordinate, 0.0, 1.0);
    topCoordinate = clamp(topCoordinate, 0.0, 1.0);
    bottomCoordinate = clamp(bottomCoordinate, 0.0, 1.0);
    
    uint2 leftCoord = uint2(leftCoordinate * float2(width, height));
    uint2 rightCoord = uint2(rightCoordinate * float2(width, height));
    uint2 topCoord = uint2(topCoordinate * float2(width, height));
    uint2 bottomCoord = uint2(bottomCoordinate * float2(width, height));
    
    const half4 leftColor = inputTexture.read(leftCoord);
    const half4 rightColor = inputTexture.read(rightCoord);
    const half4 topColor = inputTexture.read(topCoord);
    const half4 bottomColor = inputTexture.read(bottomCoord);
    
    const half centerMultiplier = 1.0h + 4.0h * half(*sharpeness);
    const half edgeMultiplier = half(*sharpeness);
    const half3 rgb = (inColor.rgb * centerMultiplier - (leftColor.rgb + rightColor.rgb + topColor.rgb + bottomColor.rgb) * edgeMultiplier);
    const half4 outColor = half4(rgb, bottomColor.a);
    
    outputTexture.write(outColor, grid);
}
