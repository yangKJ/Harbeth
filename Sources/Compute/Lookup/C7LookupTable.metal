//
//  C7LookupTable.metal
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LookupTable(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> lookupTexture [[texture(2)]],
                          constant float *intensity [[buffer(0)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half blueColor = inColor.b * 63.0h; // 蓝色部分[0, 63] 共64种
    
    half2 quad1;
    quad1.y = floor(floor(blueColor) / 8.0h);
    quad1.x = floor(blueColor) - (quad1.y * 8.0h);
    
    half2 quad2;
    quad2.y = floor(ceil(blueColor) / 8.0h);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0h);
    
    const float A = 0.125;
    const float B = 0.5 / 512.0;
    const float C = 0.125 - 1.0 / 512.0;
    
    float2 texPos1; // 计算颜色(r,b,g)在第一个正方形中对应位置
    texPos1.x = A * quad1.x + B + C * inColor.r;
    texPos1.y = A * quad1.y + B + C * inColor.g;
    
    float2 texPos2;
    texPos2.x = A * quad2.x + B + C * inColor.r;
    texPos2.y = A * quad2.y + B + C * inColor.g;
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 newColor1 = lookupTexture.sample(quadSampler, texPos1);
    const half4 newColor2 = lookupTexture.sample(quadSampler, texPos2);
    
    const half4 newColor = mix(newColor1, newColor2, fract(blueColor));
    const half4 outColor = half4(mix(inColor, half4(newColor.rgb, inColor.a), half(*intensity)));
    
    outputTexture.write(outColor, grid);
}
