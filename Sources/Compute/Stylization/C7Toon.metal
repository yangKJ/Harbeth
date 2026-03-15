//
//  C7Toon.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Toon(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::read> inputTexture [[texture(1)]],
                   constant float *threshold [[buffer(0)]],
                   constant float *quantizationLevels [[buffer(1)]],
                   uint2 grid [[thread_position_in_grid]]) {
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        outputTexture.write(half4(0.0h), grid);
        return;
    }
    
    const half4 inColor = inputTexture.read(pos);
    int px = int(pos.x);
    int py = int(pos.y);
    
    uint2 leftPos = uint2(clamp(px - 1, 0, width - 1), py);
    uint2 rightPos = uint2(clamp(px + 1, 0, width - 1), py);
    uint2 topPos = uint2(px, clamp(py - 1, 0, height - 1));
    uint2 bottomPos = uint2(px, clamp(py + 1, 0, height - 1));
    uint2 topLeftPos = uint2(clamp(px - 1, 0, width - 1), clamp(py - 1, 0, height - 1));
    uint2 topRightPos = uint2(clamp(px + 1, 0, width - 1), clamp(py - 1, 0, height - 1));
    uint2 bottomLeftPos = uint2(clamp(px - 1, 0, width - 1), clamp(py + 1, 0, height - 1));
    uint2 bottomRightPos = uint2(clamp(px + 1, 0, width - 1), clamp(py + 1, 0, height - 1));
    
    const half leftIntensity = inputTexture.read(leftPos).r;
    const half rightIntensity = inputTexture.read(rightPos).r;
    const half topIntensity = inputTexture.read(topPos).r;
    const half bottomIntensity = inputTexture.read(bottomPos).r;
    const half topLeftIntensity = inputTexture.read(topLeftPos).r;
    const half topRightIntensity = inputTexture.read(topRightPos).r;
    const half bottomLeftIntensity = inputTexture.read(bottomLeftPos).r;
    const half bottomRightIntensity = inputTexture.read(bottomRightPos).r;
    
    const half h = -topLeftIntensity - 2.0h * topIntensity - topRightIntensity + bottomLeftIntensity + 2.0h * bottomIntensity + bottomRightIntensity;
    const half v = -bottomLeftIntensity - 2.0h * leftIntensity - topLeftIntensity + bottomRightIntensity + 2.0h * rightIntensity + topRightIntensity;
    
    const half mag = length(half2(h, v));
    const half3 posterizedImageColor = floor((inColor.rgb * half3(*quantizationLevels)) + 0.5h) / half3(*quantizationLevels);
    const half thresholdTest = 1.0h - step(half(*threshold), mag);
    
    const half4 outColor = half4(posterizedImageColor * thresholdTest, inColor.a);
    
    outputTexture.write(outColor, grid);
}
