//
//  C7LookupTable1D.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LookupTable1D(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            texture2d<half, access::sample> lookupTexture [[texture(2)]],
                            constant float *intensity [[buffer(0)]],
                            constant float *domainPolicy [[buffer(1)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const float strength = intensity[0];
    const bool preservesOutsideDomain = domainPolicy[0] >= 0.5f;
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 lookup;
    lookup.y = 0.5;
    
    half4 lookupColor = inColor;
    lookup.x = float(inColor.r);
    if (!preservesOutsideDomain || (lookup.x >= 0.0 && lookup.x <= 1.0)) lookupColor.r = lookupTexture.sample(s, lookup).r;
    
    lookup.x = float(inColor.g);
    if (!preservesOutsideDomain || (lookup.x >= 0.0 && lookup.x <= 1.0)) lookupColor.g = lookupTexture.sample(s, lookup).g;
    
    lookup.x = float(inColor.b);
    if (!preservesOutsideDomain || (lookup.x >= 0.0 && lookup.x <= 1.0)) lookupColor.b = lookupTexture.sample(s, lookup).b;
    
    lookupColor.a = inColor.a;
    
    half4 finalColor = mix(inColor, lookupColor, half(strength));
    
    half4 outColor = finalColor;
    
    outputTexture.write(outColor, grid);
}
