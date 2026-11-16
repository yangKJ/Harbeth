//
//  C7PolarPixellate.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7PolarPixellate(texture2d<float, access::write> outputTexture [[texture(0)]],
                             texture2d<float, access::read> inputTexture [[texture(1)]],
                             constant float *pixelScale [[buffer(0)]],
                             constant float *centerX [[buffer(1)]],
                             constant float *centerY [[buffer(2)]],
                             uint2 grid [[thread_position_in_grid]]) {
    
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    if (!isfinite(*pixelScale) || *pixelScale <= 0.0f) { outputTexture.write(inputTexture.read(uint2(clamp(int2(grid), int2(0), int2(inputTexture.get_width()-1, inputTexture.get_height()-1)))), grid); return; }
    float2 normCoord = 2.0 * textureCoordinate - 1.0;
    const float2 normCenter = 2.0 * float2(*centerX, *centerY) - 1.0;
    
    normCoord -= normCenter;
    
    float r = length(normCoord); // to polar coords
    float phi = atan2(normCoord.y, normCoord.x); // to polar coords
    
    float2 size = float2(*pixelScale, *pixelScale);
    const float m1 = r - size.x * floor(r / size.x);
    const float m2 = phi - size.y * floor(phi / size.y);
    r = r - m1 + 0.03;
    phi = phi - m2;
    
    normCoord.x = r * cos(phi);
    normCoord.y = r * sin(phi);
    
    normCoord += normCenter;
    
    const float2 textureCoordinateToUse = normCoord / 2.0 + 0.5;
    float2 clampedCoord = clamp(textureCoordinateToUse, 0.0, 1.0);
    uint2 texCoord = uint2(clamp(clampedCoord * float2(inputTexture.get_width(), inputTexture.get_height()), float2(0), float2(inputTexture.get_width()-1, inputTexture.get_height()-1)));
    const float4 outColor = inputTexture.read(texCoord);
    
    outputTexture.write(outColor, grid);
}
