//
//  C7PolarPixellate.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7PolarPixellate(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::sample> inputTexture [[texture(1)]],
                             constant float *pixelWidth [[buffer(0)]],
                             constant float *pixelHeight [[buffer(1)]],
                             constant float *centerX [[buffer(2)]],
                             constant float *centerY [[buffer(3)]],
                             uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    float2 normCoord = 2.0 * textureCoordinate - 1.0;
    const float2 normCenter = 2.0 * float2(*centerX, *centerY) - 1.0;
    
    normCoord -= normCenter;
    
    float r = length(normCoord); // to polar coords
    float phi = atan2(normCoord.y, normCoord.x); // to polar coords
    
    float2 size = float2(*pixelWidth, *pixelHeight);
    const float m1 = r - size.x * floor(r / size.x);
    const float m2 = phi - size.y * floor(phi / size.y);
    r = r - m1 + 0.03;
    phi = phi - m2;
    
    normCoord.x = r * cos(phi);
    normCoord.y = r * sin(phi);
    
    normCoord += normCenter;
    
    const float2 textureCoordinateToUse = normCoord / 2.0 + 0.5;
    const half4 outColor = inputTexture.sample(quadSampler, textureCoordinateToUse);
    
    outputTexture.write(outColor, grid);
}
