//
//  C7CircleBlur.metal
//  Harbeth
//
//  Created by Condy on 2023/8/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CircleBlur(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *blurRadius [[buffer(0)]],
                         constant float *sampleCountPointer [[buffer(1)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const float2 textureCoordinate = float2(grid) / float2(outputTexture.get_width(), outputTexture.get_height());
    const half radius = half(*blurRadius) / 100.0h;
    const half sampleCount = half(*sampleCountPointer);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());
    
    half4 result = half4(0.0h);
    for (int i = 0; i < sampleCount; ++i) {
        float fraction = float(i) / sampleCount;
        float x = textureCoordinate.x;
        float y = textureCoordinate.y;
        float angle = fraction * M_PI_F * 2;
        x += cos(angle) * radius;
        y += sin(angle) * radius;
        
        // Convert normalized coordinates to pixel coordinates
        float2 coord = float2(x, y) * float2(width, height);
        uint2 pixel = uint2(coord.x, coord.y);
        // Clamp to texture bounds
        pixel.x = clamp(pixel.x, 0u, inputTexture.get_width() - 1u);
        pixel.y = clamp(pixel.y, 0u, inputTexture.get_height() - 1u);
        
        const half4 sample = inputTexture.read(pixel);
        result += sample;
    }
    
    const half4 outColor = result / sampleCount;
    outputTexture.write(outColor, grid);
}
