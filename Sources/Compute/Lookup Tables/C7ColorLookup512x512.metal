//
//  C7ColorLookup512x512.metal
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorLookup512x512(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 texture2d<half, access::sample> lookupTexture [[texture(2)]],
                                 constant float *intensity [[buffer(0)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    constexpr sampler lookupSampler(mag_filter::linear, min_filter::linear);
    
    half3 color = inColor.rgb;
    float size = 512.0;
    float2 lookupCoord;
    
    float3 scaledColor = float3(color) * 31.0;
    float3 floorColor = floor(scaledColor);
    float3 fracColor = scaledColor - floorColor;
    
    int z = int(floorColor.z);
    int tileSize = 32;
    int tileX = z % 16;
    int tileY = z / 16;
    
    float2 tileOffset = float2(float(tileX) * float(tileSize), float(tileY) * float(tileSize));
    float2 texCoord = float2(fracColor.x, fracColor.y) * float(tileSize - 1) + 0.5;
    lookupCoord = (tileOffset + texCoord) / size;
    
    half4 lookupColor = lookupTexture.sample(lookupSampler, lookupCoord);
    half4 outColor = mix(inColor, lookupColor, half(*intensity));
    
    outputTexture.write(outColor, grid);
}
