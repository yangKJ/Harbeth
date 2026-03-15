//
//  C7ZoomBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ZoomBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *blurCenterX [[buffer(0)]],
                       constant float *blurCenterY [[buffer(1)]],
                       constant float *radius [[buffer(2)]],
                       uint2 grid [[thread_position_in_grid]]) {
    
    const float2 blurCenter = float2(*blurCenterX, *blurCenterY);
    const float2 textureCoord = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const float2 offset = 1.0 / 100.0 * (blurCenter - textureCoord) * float(*radius);
    const float w = float(inputTexture.get_width());
    const float h = float(inputTexture.get_height());
    
    float2 clampedCoord = clamp(textureCoord, 0.0, 1.0);
    uint2 texCoord = uint2(clampedCoord * float2(w, h));
    half4 outColor = inputTexture.read(texCoord) * 0.18;
    
    clampedCoord = clamp(textureCoord + (1.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.15h;
    
    clampedCoord = clamp(textureCoord + (2.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.12h;
    
    clampedCoord = clamp(textureCoord + (3.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.09h;
    
    clampedCoord = clamp(textureCoord + (4.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.05h;
    
    clampedCoord = clamp(textureCoord - (1.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.15h;
    
    clampedCoord = clamp(textureCoord - (2.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.12h;
    
    clampedCoord = clamp(textureCoord - (3.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.09h;
    
    clampedCoord = clamp(textureCoord - (4.0 * offset), 0.0, 1.0);
    texCoord = uint2(clampedCoord * float2(w, h));
    outColor += inputTexture.read(texCoord) * 0.05h;
    
    outputTexture.write(outColor, grid);
}
