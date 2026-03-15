//
//  C7Pinch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Pinch(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *centerPointerX [[buffer(0)]],
                    constant float *centerPointerY [[buffer(1)]],
                    constant float *radiusPointer [[buffer(2)]],
                    constant float *scalePointer [[buffer(3)]],
                    uint2 grid [[thread_position_in_grid]]) {
    
    const float2 center = float2(*centerPointerX, *centerPointerY);
    const float radius = float(*radiusPointer);
    const float scale = float(*scalePointer);
    const float aspectRatio = float(inputTexture.get_height()) / float(inputTexture.get_width());
    
    const float2 inCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    float2 textureCoordinateToUse = float2(inCoordinate.x, inCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio);
    const float dist = distance(center, textureCoordinateToUse);
    textureCoordinateToUse = inCoordinate;
    
    if (dist < radius) {
        textureCoordinateToUse -= center;
        float percent = 1.0 + (0.5 - dist) / 0.5 * scale;
        textureCoordinateToUse = textureCoordinateToUse * percent + center;
    }
    
    float2 clampedCoord = clamp(textureCoordinateToUse, 0.0, 1.0);
    uint2 texCoord = uint2(clampedCoord * float2(inputTexture.get_width(), inputTexture.get_height()));
    const half4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(outColor, grid);
}
