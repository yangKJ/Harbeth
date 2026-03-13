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
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const float strength = intensity[0];
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 lookup;
    lookup.y = 0.5;
    
    lookup.x = float(inColor.r);
    half4 lookupColor;
    lookupColor.r = lookupTexture.sample(s, lookup).r;
    
    lookup.x = float(inColor.g);
    lookupColor.g = lookupTexture.sample(s, lookup).g;
    
    lookup.x = float(inColor.b);
    lookupColor.b = lookupTexture.sample(s, lookup).b;
    
    lookupColor.a = inColor.a;
    
    half4 finalColor = mix(inColor, lookupColor, half(strength));
    
    half4 outColor;
    outColor.r = clamp(finalColor.r, 0.0h, 1.0h);
    outColor.g = clamp(finalColor.g, 0.0h, 1.0h);
    outColor.b = clamp(finalColor.b, 0.0h, 1.0h);
    outColor.a = clamp(finalColor.a, 0.0h, 1.0h);
    
    outputTexture.write(outColor, grid);
}
