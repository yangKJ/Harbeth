//
//  C7FusedPointOperations.metal
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7FusedPointOperations(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   constant float2 *operations [[buffer(0)]],
                                   constant int &operationCount [[buffer(1)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    half4 color = inputTexture.read(grid);
    for (int index = 0; index < operationCount; ++index) {
        const int kind = int(operations[index].x);
        const float value = operations[index].y;
        switch (kind) {
            case 0:
                color = half4(color.rgb + half3(half(value)), color.a);
                break;
            case 1:
                color = half4(half3(0.5h) + (color.rgb - half3(0.5h)) * value, color.a);
                break;
            case 2: {
                const half luminance = dot(color.rgb, half3(0.2125h, 0.7154h, 0.0721h));
                color = half4(mix(half3(luminance), color.rgb, half(value)), color.a);
                break;
            }
            case 3:
                color = half4(color.rgb * half(pow(2.0f, value)), color.a);
                break;
            case 4:
                color = half4(pow(color.rgb, half3(half(value))), color.a);
                break;
            case 5:
                color = half4(color.rgb, half(value) * color.a);
                break;
            default:
                break;
        }
    }
    outputTexture.write(color, grid);
}
