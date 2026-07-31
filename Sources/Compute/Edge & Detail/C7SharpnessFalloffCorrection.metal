//
//  C7SharpnessFalloffCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

static half4 safeRead(texture2d<half, access::read> texture, int2 coordinate) {
    int2 clamped = int2(
        clamp(coordinate.x, 0, int(texture.get_width()) - 1),
        clamp(coordinate.y, 0, int(texture.get_height()) - 1)
    );
    return texture.read(uint2(clamped));
}

kernel void C7SharpnessFalloffCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                                         texture2d<half, access::read> inputTexture [[texture(1)]],
                                         constant float2 &center [[buffer(0)]],
                                         constant float2 &falloff [[buffer(1)]],
                                         constant float &amount [[buffer(2)]],
                                         constant float &edgeThreshold [[buffer(3)]],
                                         uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    half4 centerColor = inputTexture.read(grid);

    float2 uv = float2(
        (float(grid.x) + 0.5f) / float(outputTexture.get_width()),
        (float(grid.y) + 0.5f) / float(outputTexture.get_height())
    );
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float maxDimension = max(size.x, size.y);
    float2 radial = (uv - center) * size / maxDimension;
    float radius = length(radial);
    float radialWeight = smoothstep(falloff.x, max(falloff.y, falloff.x + 0.0001f), radius) * clamp(amount, 0.0f, 1.0f);

    constexpr int kernelSize = 3;
    const half laplacianKernel[9] = {
        0.0h,  1.0h, 0.0h,
        1.0h, -4.0h, 1.0h,
        0.0h,  1.0h, 0.0h
    };

    half4 laplacianSum = half4(0.0h);
    int2 coordinate = int2(grid);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            half4 sampleColor = safeRead(inputTexture, coordinate + int2(x, y));
            int kernelIndex = (y + 1) * kernelSize + (x + 1);
            laplacianSum += sampleColor * laplacianKernel[kernelIndex];
        }
    }

    half edgeStrength = dot(abs(laplacianSum.rgb), half3(0.299h, 0.587h, 0.114h));
    edgeStrength = saturate(edgeStrength / 4.0h);

    half sharpenIntensity = 0.0h;
    if (edgeStrength > half(edgeThreshold)) {
        half normalizedEdge = (edgeStrength - half(edgeThreshold)) / max(0.0001h, 1.0h - half(edgeThreshold));
        sharpenIntensity = half(radialWeight) * normalizedEdge;
    }

    half4 sharpenedColor = centerColor - laplacianSum * sharpenIntensity * 0.25h;
    sharpenedColor.a = centerColor.a;
    outputTexture.write(sharpenedColor, grid);
}
