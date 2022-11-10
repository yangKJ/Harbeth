//
//  C7LookupSplit.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LookupSplit(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          texture2d<half, access::sample> inputTexture2 [[texture(2)]],
                          texture2d<half, access::sample> inputTexture3 [[texture(3)]],
                          constant float *intensity [[buffer(0)]],
                          constant float *progress [[buffer(1)]],
                          constant float *orientation [[buffer(2)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half blueColor = inColor.b * 63.0h;
    
    half2 quad1;
    quad1.y = floor(floor(blueColor) / 8.0h);
    quad1.x = floor(blueColor) - (quad1.y * 8.0h);
    
    half2 quad2;
    quad2.y = floor(ceil(blueColor) / 8.0h);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0h);
    
    const float A = 0.125;
    const float B = 0.5 / 512.0;
    const float C = 0.125 - 1.0 / 512.0;
    
    float2 texPos1;
    texPos1.x = A * quad1.x + B + C * inColor.r;
    texPos1.y = A * quad1.y + B + C * inColor.g;
    
    float2 texPos2;
    texPos2.x = A * quad2.x + B + C * inColor.r;
    texPos2.y = A * quad2.y + B + C * inColor.g;
    
    // 归一化坐标系
    const half x = half(grid.x) / outputTexture.get_width();
    const half y = half(grid.y) / outputTexture.get_height();
    const half p = half(*progress);
    bool result = false;
    
    if (*orientation == 0.0) { // top
        result = y > p;
    } else if (*orientation == 1.0) { // left
        result = x > p;
    } else if (*orientation == 2.0) { // center
        half xx = abs(x - 0.5);
        half yy = abs(y - 0.5);
        half l = length(half2(xx, yy));
        result = l > p / 2;
    } else if (*orientation == 3.0) { // topLeft
        // x^2 + y^2 开根号
        half l = length(half2(x, y));
        result = l / sqrt(2.0) > p;
    } else if (*orientation == 4.0) { // bottomLeft
        result = length(half2(x, 1-y)) / sqrt(2.0) > p;
    }
    
    if (result) {
        constexpr sampler quadSampler3;
        half4 newColor1 = inputTexture2.sample(quadSampler3, texPos1);
        constexpr sampler quadSampler4;
        half4 newColor2 = inputTexture2.sample(quadSampler4, texPos2);
        half4 newColor = mix(newColor1, newColor2, fract(blueColor));
        const half4 outColor = half4(mix(inColor, half4(newColor.rgb, inColor.w), 1.0h));
        outputTexture.write(outColor, grid);
    } else {
        constexpr sampler quadSampler3;
        half4 newColor1 = inputTexture3.sample(quadSampler3, texPos1);
        constexpr sampler quadSampler4;
        half4 newColor2 = inputTexture3.sample(quadSampler4, texPos2);
        half4 newColor = mix(newColor1, newColor2, fract(blueColor));
        const half4 outColor = half4(mix(inColor, half4(newColor.rgb, inColor.w), half(*intensity)));
        outputTexture.write(outColor, grid);
    }
}
