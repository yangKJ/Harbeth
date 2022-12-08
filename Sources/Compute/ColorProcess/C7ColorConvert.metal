//
//  C7ColorConvert.metal
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

#include <metal_stdlib>
using namespace metal;

// 颜色反转，1 - rgb
kernel void C7ColorInvert(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::read> inputTexture [[texture(1)]],
                          uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(1.0h - inColor.rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}

// 转灰度图
kernel void C7Color2Gray(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    // 权值法
    const half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);
    const half gray = dot(inColor.rgb, kRec709Luma);
    const half4 outColor = half4(half3(gray), 1.0h);
    
    outputTexture.write(outColor, grid);
}

kernel void C7Color2BGRA(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(inColor.bgr, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7Color2BRGA(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(inColor.brg, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7Color2GBRA(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(inColor.gbr, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7Color2GRBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(inColor.grb, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7Color2RBGA(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half4 outColor(inColor.rbg, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7Color2Y(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half Y = half((0.299 * inColor.r) + (0.587 * inColor.g) + (0.114 * inColor.b));
    const half4 outColor = half4(Y, Y, Y, 1.0h);
    
    outputTexture.write(outColor, grid);
}
