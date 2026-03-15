//
//  C7ThresholdSketch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ThresholdSketch(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *edgeStrength [[buffer(0)]],
                              constant float *threshold [[buffer(1)]],
                              uint2 grid [[thread_position_in_grid]]) {
    
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    float2 leftCoordinate = float2((x - 1) / width, y / height);
    float2 rightCoordinate = float2((x + 1) / width, y / height);
    float2 topCoordinate = float2(x / width, (y - 1) / height);
    float2 bottomCoordinate = float2(x / width, (y + 1) / height);
    float2 topLeftCoordinate = float2((x - 1) / width, (y - 1) / height);
    float2 topRightCoordinate = float2((x + 1) / width, (y - 1) / height);
    float2 bottomLeftCoordinate = float2((x - 1) / width, (y + 1) / height);
    float2 bottomRightCoordinate = float2((x + 1) / width, (y + 1) / height);
    
    leftCoordinate = clamp(leftCoordinate, 0.0, 1.0);
    rightCoordinate = clamp(rightCoordinate, 0.0, 1.0);
    topCoordinate = clamp(topCoordinate, 0.0, 1.0);
    bottomCoordinate = clamp(bottomCoordinate, 0.0, 1.0);
    topLeftCoordinate = clamp(topLeftCoordinate, 0.0, 1.0);
    topRightCoordinate = clamp(topRightCoordinate, 0.0, 1.0);
    bottomLeftCoordinate = clamp(bottomLeftCoordinate, 0.0, 1.0);
    bottomRightCoordinate = clamp(bottomRightCoordinate, 0.0, 1.0);
    
    uint2 leftCoord = uint2(leftCoordinate * float2(width, height));
    uint2 rightCoord = uint2(rightCoordinate * float2(width, height));
    uint2 topCoord = uint2(topCoordinate * float2(width, height));
    uint2 bottomCoord = uint2(bottomCoordinate * float2(width, height));
    uint2 topLeftCoord = uint2(topLeftCoordinate * float2(width, height));
    uint2 topRightCoord = uint2(topRightCoordinate * float2(width, height));
    uint2 bottomLeftCoord = uint2(bottomLeftCoordinate * float2(width, height));
    uint2 bottomRightCoord = uint2(bottomRightCoordinate * float2(width, height));
    
    const half leftIntensity = inputTexture.read(leftCoord).r;
    const half rightIntensity = inputTexture.read(rightCoord).r;
    const half topIntensity = inputTexture.read(topCoord).r;
    const half bottomIntensity = inputTexture.read(bottomCoord).r;
    const half topLeftIntensity = inputTexture.read(topLeftCoord).r;
    const half topRightIntensity = inputTexture.read(topRightCoord).r;
    const half bottomLeftIntensity = inputTexture.read(bottomLeftCoord).r;
    const half bottomRightIntensity = inputTexture.read(bottomRightCoord).r;
    
    half h = -topLeftIntensity - 2.0h * topIntensity - topRightIntensity + bottomLeftIntensity + 2.0h * bottomIntensity + bottomRightIntensity;
    h = max(0.0h, h);
    half v = -bottomLeftIntensity - 2.0h * leftIntensity - topLeftIntensity + bottomRightIntensity + 2.0h * rightIntensity + topRightIntensity;
    v = max(0.0h, v);
    
    half mag = length(half2(h, v)) * half(*edgeStrength);
    mag = 1.0h - step(half(*threshold), mag);
    
    const half4 outColor = half4(half3(mag), 1.0h);
    outputTexture.write(outColor, grid);
}
