//
//  C7WhitesBlacks.metal
//  Harbeth
//
//  Created by Condy on 2026/7/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7WhitesBlacks(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::read> inputTexture [[texture(1)]],
                           constant float *whites [[buffer(0)]],
                           constant float *blacks [[buffer(1)]],
                           uint2 grid [[thread_position_in_grid]]) {
    const half4 input = inputTexture.read(grid);
    const float3 source = float3(input.rgb);
    const float3 boundedSource = clamp(source, 0.0, 1.0);
    float3 color = boundedSource;
    const float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    const float whiteWeight = smoothstep(0.50, 1.0, luminance);
    const float blackWeight = 1.0 - smoothstep(0.0, 0.50, luminance);

    const float whiteAmount = clamp(*whites, -1.0, 1.0) * whiteWeight * 0.45;
    color = whiteAmount >= 0.0
        ? mix(color, float3(1.0), whiteAmount)
        : color * (1.0 + whiteAmount);

    const float blackAmount = clamp(*blacks, -1.0, 1.0) * blackWeight * 0.45;
    color = blackAmount >= 0.0
        ? mix(color, float3(1.0), blackAmount)
        : color * (1.0 + blackAmount);

    // 调色只作用于 SDR 主体，保留扩展动态范围分量，避免 HDR 工作管线被隐式截断。
    color += source - boundedSource;
    outputTexture.write(half4(half3(color), input.a), grid);
}
