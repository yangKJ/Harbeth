//
//  C7Crosshatch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

float C7CrosshatchMod(float x, float y) {
    return x - y * floor(x / y);
}

kernel void C7Crosshatch(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *crossHatchSpacingPointer [[buffer(0)]],
                         constant float *lineWidthPointer [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float crossHatchSpacing = float(*crossHatchSpacingPointer);
    const float lineWidth = float(*lineWidthPointer);
    
    const half3 luminanceWeighting = half3(0.2125, 0.7154, 0.0721);
    const half luminance = dot(inColor.rgb, luminanceWeighting);
    
    const bool displayBlack = ((luminance < 1.00) && (C7CrosshatchMod(textureCoordinate.x + textureCoordinate.y, crossHatchSpacing) <= lineWidth)) ||
    ((luminance < 0.75) && (C7CrosshatchMod(textureCoordinate.x - textureCoordinate.y, crossHatchSpacing) <= lineWidth)) ||
    ((luminance < 0.50) && (C7CrosshatchMod(textureCoordinate.x + textureCoordinate.y - (crossHatchSpacing / 2.0), crossHatchSpacing) <= lineWidth)) ||
    ((luminance < 0.3) && (C7CrosshatchMod(textureCoordinate.x - textureCoordinate.y - (crossHatchSpacing / 2.0), crossHatchSpacing) <= lineWidth));
    
    const half4 outColor = displayBlack ? half4(0.0, 0.0, 0.0, 1.0) : half4(1.0);
    
    outputTexture.write(outColor, grid);
}

