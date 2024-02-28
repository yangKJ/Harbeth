//
//  C7Grayed.metal
//  Harbeth
//
//  Created by Condy on 2024/2/28.
//

#include <metal_stdlib>
using namespace metal;

// 亮度算法，权重算法
kernel void C7GrayedLuminosity(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> inputTexture [[texture(1)]],
                               constant float *intensity [[buffer(0)]],
                               uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half gray = (0.299 * inColor.r) + (0.587 * inColor.g) + (0.114 * inColor.b);
    const half4 outColor = half4(half3(gray), 1.0h);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}

// 去饱和
kernel void C7GrayedDesaturation(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 constant float *intensity [[buffer(0)]],
                                 uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half max_ = max(inColor.r, max(inColor.g, inColor.b));
    const half min_ = min(inColor.r, min(inColor.g, inColor.b));
    const half gray = (max_ + min_) * 0.5;
    const half4 outColor = half4(half3(gray), 1.0h);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}

// 平均值
kernel void C7GrayedAverage(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *intensity [[buffer(0)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half gray = (inColor.r + inColor.g + inColor.b) / 3.0;
    const half4 outColor = half4(half3(gray), 1.0h);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}

// 最大值
kernel void C7GrayedMaximum(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *intensity [[buffer(0)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half gray = max(inColor.r, max(inColor.g, inColor.b));
    const half4 outColor = half4(half3(gray), 1.0h);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}

// 最小值
kernel void C7GrayedMinimum(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *intensity [[buffer(0)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half gray = min(inColor.r, min(inColor.g, inColor.b));
    const half4 outColor = half4(half3(gray), 1.0h);
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}

// 单一通道
kernel void C7GrayedSingleChannel(texture2d<half, access::write> outputTexture [[texture(0)]],
                                  texture2d<half, access::read> inputTexture [[texture(1)]],
                                  constant float *intensity [[buffer(0)]],
                                  constant float *channel [[buffer(1)]],
                                  uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    half4 outColor;
    if (*channel == 0.0) {
        outColor = half4(half3(inColor.r), 1.0h);
    } else if (*channel == 1) {
        outColor = half4(half3(inColor.g), 1.0h);
    } else if (*channel == 2) {
        outColor = half4(half3(inColor.b), 1.0h);
    } else {
        outColor = inColor;
    }
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
