//
//  C7Crosshatch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

namespace crosshatch {
    METAL_FUNC float mod(float x, float y) {
        return x - y * floor(x / y);
    }
}

kernel void C7Crosshatch(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *crossHatchSpacingPointer [[buffer(0)]],
                         constant float *lineWidthPointer [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const float2 coordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float spacing = float(*crossHatchSpacingPointer);
    const float lineWidth = float(*lineWidthPointer);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    
    const bool black1 = (luminance < 1.00) && (crosshatch::mod(coordinate.x + coordinate.y, spacing) <= lineWidth);
    const bool black2 = (luminance < 0.75) && (crosshatch::mod(coordinate.x - coordinate.y, spacing) <= lineWidth);
    const bool black3 = (luminance < 0.50) && (crosshatch::mod(coordinate.x + coordinate.y - (spacing / 2.0), spacing) <= lineWidth);
    const bool black4 = (luminance < 0.30) && (crosshatch::mod(coordinate.x - coordinate.y - (spacing / 2.0), spacing) <= lineWidth);
    const bool displayBlack = black1 || black2 || black3 || black4;
    
    const half4 outColor = displayBlack ? half4(0.0h, 0.0h, 0.0h, 1.0h) : half4(1.0h);
    outputTexture.write(outColor, grid);
}

