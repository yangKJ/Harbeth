//
//  PixelReplacementFilter.metal
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

#include <metal_stdlib>
using namespace metal;

kernel void PixelReplacementFilter(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> blurredTexture [[texture(1)]],
    texture2d<half, access::read> originalTexture [[texture(2)]],
    texture2d<half, access::read> selectionTexture [[texture(3)]],
    constant float &opacity [[buffer(0)]],
    constant bool &preservesTransparency [[buffer(1)]],
    constant bool &usesSelection [[buffer(2)]],
    uint2 grid [[thread_position_in_grid]]) {
    half4 blurred = blurredTexture.read(grid);
    half4 original = originalTexture.read(grid);
    half coverage = half(opacity);
    if (usesSelection) {
        coverage *= selectionTexture.read(grid).r;
    }
    half4 next = blurred;
    if (preservesTransparency) {
        next.a = original.a;
        if (original.a == 0) {
            next.rgb = half3(0);
        } else if (blurred.a > 0) {
            next.rgb = min(original.a, blurred.rgb * original.a / blurred.a);
        } else {
            next.rgb = original.rgb;
        }
    }
    outputTexture.write(half4(mix(original, next, coverage)), grid);
}
