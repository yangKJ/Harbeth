//
//  C7SharpenDetail.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7SharpenDetail(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float *sharpen [[buffer(0)]],
                            constant float *clarity [[buffer(1)]],
                            constant float *detail [[buffer(2)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half sharpenAmount = half(*sharpen);
    const half clarityAmount = half(*clarity);
    const half detailAmount = half(*detail);
    
    half3 color = inColor.rgb;
    
    if (sharpenAmount > 0.0h) {
        const float3x3 sharpenKernel = float3x3(-1.0, -1.0, -1.0,
                                                -1.0, 9.0, -1.0,
                                                -1.0, -1.0, -1.0);
        half3 sharpenedColor = half3(0.0h, 0.0h, 0.0h);
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                uint2 offset = uint2(clamp(int(grid.x) + x, 0, int(inputTexture.get_width() - 1)),
                                     clamp(int(grid.y) + y, 0, int(inputTexture.get_height() - 1)));
                half3 sample = inputTexture.read(offset).rgb;
                sharpenedColor += sample * half(sharpenKernel[x + 1][y + 1]);
            }
        }
        color = mix(color, sharpenedColor, sharpenAmount);
    }

    if (clarityAmount > 0.0h) {
        half3 localMean = half3(0.0h);
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                uint2 offset = uint2(clamp(int(grid.x) + x, 0, int(inputTexture.get_width() - 1)),
                                     clamp(int(grid.y) + y, 0, int(inputTexture.get_height() - 1)));
                localMean += inputTexture.read(offset).rgb;
            }
        }
        localMean /= 9.0h;
        const half3 luminanceWeighting = half3(0.2125h, 0.7154h, 0.0721h);
        const half luminance = dot(color, luminanceWeighting);
        const half midtoneDistance = abs(luminance - 0.5h) * 2.0h;
        const half midtoneMask = 1.0h - smoothstep(0.35h, 0.9h, midtoneDistance);
        color += (color - localMean) * clarityAmount * midtoneMask * 0.75h;
    }

    if (detailAmount > 0.0h) {
        const float3x3 detailKernel = float3x3(0.0, -0.25, 0.0,
                                               -0.25, 2.0, -0.25,
                                               0.0, -0.25, 0.0);
        half3 detailedColor = half3(0.0h, 0.0h, 0.0h);
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                uint2 offset = uint2(clamp(int(grid.x) + x, 0, int(inputTexture.get_width() - 1)),
                                     clamp(int(grid.y) + y, 0, int(inputTexture.get_height() - 1)));
                half3 sample = inputTexture.read(offset).rgb;
                detailedColor += sample * half(detailKernel[x + 1][y + 1]);
            }
        }
        color = mix(color, detailedColor, detailAmount * 0.5h);
    }
    const half4 outColor = half4(color, inColor.a);
    
    outputTexture.write(outColor, grid);
}
