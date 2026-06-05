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
    
    const half3x3 RGBtoYIQ = half3x3(half3(0.299h, 0.587h, 0.114h), half3(0.596h, -0.274h, -0.322h), half3(0.212h, -0.523h, 0.311h));
    const half3 yiq = RGBtoYIQ * inColor.rgb;
    const half4 outColor = half4(yiq, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7ColorSpaceYIQ2RGB(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 YIQtoRGB = half3x3(half3(1.0h, 0.956h, 0.621h), half3(1.0h, -0.272h, -0.647h), half3(1.0h, -1.105h, 1.702h));
    const half3 rgb = YIQtoRGB * inColor.rgb;
    const half4 outColor = half4(rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}

// See: https://en.wikipedia.org/wiki/YUV
kernel void C7ColorSpaceRGB2YUV(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 RGBtoYUV = half3x3(half3(0.2126h, 0.7152h, 0.0722h), half3(-0.09991h, -0.33609h, 0.436h), half3(0.615h, -0.55861h, -0.05639h));
    const half3 yuv = RGBtoYUV * inColor.rgb;
    const half4 outColor = half4(yuv, inColor.a);
    
    outputTexture.write(outColor, grid);
}

kernel void C7ColorSpaceYUV2RGB(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> inputTexture [[texture(1)]],
                                uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3x3 YUVtoRGB = half3x3(half3(1.0h, 0.0h, 1.28033h), half3(1.0h, -0.21482h, -0.38059h), half3(1.0h, 2.21798h, 0.0h));
    const half3 rgb = YUVtoRGB * inColor.rgb;
    const half4 outColor = half4(rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
