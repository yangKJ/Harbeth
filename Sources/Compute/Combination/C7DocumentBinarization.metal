//
//  C7DocumentBinarization.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7DocumentBinarization(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<half, access::read> localBackgroundTexture [[texture(2)]],
    constant float *threshold [[buffer(0)]],
    constant float *softness [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    constexpr half3 luminanceWeights = half3(0.2126, 0.7152, 0.0722);
    const half4 source = inputTexture.read(gid);
    if (source.a <= half(0.0)) {
        outputTexture.write(half4(0.0), gid);
        return;
    }
    const half4 localBackground = localBackgroundTexture.read(gid);
    const half3 straightColor = source.rgb / source.a;
    const half3 straightBackground = localBackground.a > half(0.0)
        ? localBackground.rgb / localBackground.a
        : half3(0.0);
    const half localLuminance = dot(straightBackground, luminanceWeights);
    const half luminance = dot(straightColor, luminanceWeights);
    const half adaptiveThreshold = localLuminance * (half(1.0) - half(clamp(*threshold, 0.0f, 0.5f)));
    const half transition = half(max(*softness, 0.0f));
    const half paper = transition > half(0.0)
        ? smoothstep(adaptiveThreshold - transition, adaptiveThreshold + transition, luminance)
        : step(adaptiveThreshold, luminance);

    outputTexture.write(half4(half3(paper * source.a), source.a), gid);
}
