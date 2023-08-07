//
//  C7ColorSpace.metal
//  Harbeth
//
//  Created by Condy on 2022/12/20.
//

#include <metal_stdlib>
using namespace metal;

// See: https://en.wikipedia.org/wiki/YIQ
kernel void C7ColorSpaceRGB2YIQ(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 RGBtoYIQ = half3x3({0.299, 0.587, 0.114}, {0.596, -0.274, -0.322}, {0.212, -0.523, 0.311});
    const half3 yiq = RGBtoYIQ * inColor.rgb;
    const half4 outColor = half4(yiq, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7ColorSpaceYIQ2RGB(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 YIQtoRGB = half3x3({1.0, 0.956, 0.621}, {1.0, -0.272, -0.647}, {1.0, -1.105, 1.702});
    const half3 rgb = YIQtoRGB * inColor.rgb;
    const half4 outColor = half4(rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}

// See: https://en.wikipedia.org/wiki/YUV
kernel void C7ColorSpaceRGB2YUV(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 RGBtoYUV = half3x3({0.2126, 0.7152, 0.0722}, {-0.09991, -0.33609, 0.436}, {0.615, -0.55861, -0.05639});
    const half3 yuv = RGBtoYUV * inColor.rgb;
    const half4 outColor = half4(yuv, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7ColorSpaceYUV2RGB(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 YUVtoRGB = half3x3({1.0, 0.0, 1.28033}, {1.0, -0.21482, -0.38059}, {1.0, 2.21798, 0.0});
    const half3 rgb = YUVtoRGB * inColor.rgb;
    const half4 outColor = half4(rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
