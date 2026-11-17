//
//  C7Toon.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Toon(texture2d<float, access::write> outputTexture [[texture(0)]],
                   texture2d<float, access::read> inputTexture [[texture(1)]],
                   constant float *threshold [[buffer(0)]],
                   constant float *quantizationLevels [[buffer(1)]],
                   constant float &halfOutput [[buffer(2)]],
                   uint2 grid [[thread_position_in_grid]]) {
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    uint2 pos = grid;
    
    if (int(pos.x) >= width || int(pos.y) >= height) {
        return;
    }
    
    const float4 inColor = inputTexture.read(pos);
    const float levels = isfinite(*quantizationLevels) && *quantizationLevels > 0.0f ? *quantizationLevels : 10.0f;
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
    
    const float leftIntensity = inputTexture.read(leftPos).r;
    const float rightIntensity = inputTexture.read(rightPos).r;
    const float topIntensity = inputTexture.read(topPos).r;
    const float bottomIntensity = inputTexture.read(bottomPos).r;
    const float topLeftIntensity = inputTexture.read(topLeftPos).r;
    const float topRightIntensity = inputTexture.read(topRightPos).r;
    const float bottomLeftIntensity = inputTexture.read(bottomLeftPos).r;
    const float bottomRightIntensity = inputTexture.read(bottomRightPos).r;
    
    const float h = -topLeftIntensity - 2.0h * topIntensity - topRightIntensity + bottomLeftIntensity + 2.0h * bottomIntensity + bottomRightIntensity;
    const float v = -bottomLeftIntensity - 2.0h * leftIntensity - topLeftIntensity + bottomRightIntensity + 2.0h * rightIntensity + topRightIntensity;
    
    const float mag = length(float2(h, v));
    const float3 posterizedImageColor = floor((inColor.rgb * float3(levels)) + 0.5h) / float3(levels);
    const float thresholdTest = 1.0h - step(float(*threshold), mag);
    
    const float4 outColor = float4(posterizedImageColor * thresholdTest, inColor.a);
    
    outputTexture.write(halfOutput>0.5f?float4(half4(outColor)):outColor, grid);
}
