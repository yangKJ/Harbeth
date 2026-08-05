//
//  C7CLAHE.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

#define C7CLAHEHistogramBinCount 256u

static inline float c7CLAHELuminance(float3 color) {
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

static inline bool c7CLAHEIsSDR(float3 color) {
    return all(color >= float3(0.0f)) && all(color <= float3(1.0f));
}

static inline uint c7CLAHETileIndex(uint2 coordinate,
                                    uint2 textureSize,
                                    uint columns,
                                    uint rows) {
    const uint column = min((coordinate.x * columns) / max(textureSize.x, 1u), columns - 1u);
    const uint row = min((coordinate.y * rows) / max(textureSize.y, 1u), rows - 1u);
    return row * columns + column;
}

kernel void C7CLAHEHistogram(
    texture2d<half, access::read> inputTexture [[texture(0)]],
    device atomic_uint *histogram [[buffer(0)]],
    device atomic_uint *sampleCounts [[buffer(1)]],
    constant uint &columns [[buffer(2)]],
    constant uint &rows [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]) {
    const uint2 textureSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    if (gid.x >= textureSize.x || gid.y >= textureSize.y) {
        return;
    }

    const float4 source = float4(inputTexture.read(gid));
    if (source.a <= 0.0f) {
        return;
    }
    const float3 straightColor = source.rgb / source.a;
    if (!c7CLAHEIsSDR(straightColor)) {
        return;
    }

    const uint tileIndex = c7CLAHETileIndex(gid, textureSize, columns, rows);
    const uint bin = min(uint(c7CLAHELuminance(straightColor) * 255.0f + 0.5f), C7CLAHEHistogramBinCount - 1u);
    atomic_fetch_add_explicit(&histogram[tileIndex * C7CLAHEHistogramBinCount + bin], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&sampleCounts[tileIndex], 1u, memory_order_relaxed);
}

kernel void C7CLAHEBuildLookupTable(
    device const atomic_uint *histogram [[buffer(0)]],
    device const atomic_uint *sampleCounts [[buffer(1)]],
    device float *lookupTable [[buffer(2)]],
    constant uint &columns [[buffer(3)]],
    constant uint &rows [[buffer(4)]],
    constant float &clipLimit [[buffer(5)]],
    uint tileIndex [[thread_position_in_grid]]) {
    const uint tileCount = columns * rows;
    if (tileIndex >= tileCount) {
        return;
    }

    const uint offset = tileIndex * C7CLAHEHistogramBinCount;
    const uint sampleCount = atomic_load_explicit(&sampleCounts[tileIndex], memory_order_relaxed);
    if (sampleCount == 0u) {
        for (uint bin = 0u; bin < C7CLAHEHistogramBinCount; bin++) {
            lookupTable[offset + bin] = float(bin) / 255.0f;
        }
        return;
    }

    const uint clipCount = max(1u, uint(max(1.0f, clipLimit * float(sampleCount) / float(C7CLAHEHistogramBinCount))));
    uint excess = 0u;
    uint occupiedBinCount = 0u;
    for (uint bin = 0u; bin < C7CLAHEHistogramBinCount; bin++) {
        const uint count = atomic_load_explicit(&histogram[offset + bin], memory_order_relaxed);
        excess += count > clipCount ? count - clipCount : 0u;
        occupiedBinCount += count > 0u ? 1u : 0u;
    }
    // 单一亮度的 tile 没有可扩展的局部对比度；保持 identity，避免 clip redistribution
    // 将均匀色块推向白色或黑色。
    if (occupiedBinCount <= 1u) {
        for (uint bin = 0u; bin < C7CLAHEHistogramBinCount; bin++) {
            lookupTable[offset + bin] = float(bin) / 255.0f;
        }
        return;
    }
    const uint redistribution = excess / C7CLAHEHistogramBinCount;
    const uint remainder = excess % C7CLAHEHistogramBinCount;

    uint cdf = 0u;
    uint cdfMinimum = 0u;
    bool foundMinimum = false;
    for (uint bin = 0u; bin < C7CLAHEHistogramBinCount; bin++) {
        const uint count = atomic_load_explicit(&histogram[offset + bin], memory_order_relaxed);
        const uint clipped = min(count, clipCount) + redistribution + (bin < remainder ? 1u : 0u);
        cdf += clipped;
        if (!foundMinimum && cdf > 0u) {
            cdfMinimum = cdf;
            foundMinimum = true;
        }
        const uint denominator = sampleCount > cdfMinimum ? sampleCount - cdfMinimum : 0u;
        lookupTable[offset + bin] = denominator > 0u
            ? clamp(float(cdf - cdfMinimum) / float(denominator), 0.0f, 1.0f)
            : float(bin) / 255.0f;
    }
}

kernel void C7CLAHEApply(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    device const float *lookupTable [[buffer(0)]],
    constant uint &columns [[buffer(1)]],
    constant uint &rows [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]) {
    const uint2 textureSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    if (gid.x >= textureSize.x || gid.y >= textureSize.y) {
        return;
    }

    const float4 source = float4(inputTexture.read(gid));
    if (source.a <= 0.0f) {
        outputTexture.write(half4(source), gid);
        return;
    }
    const float3 straightColor = source.rgb / source.a;
    if (!c7CLAHEIsSDR(straightColor)) {
        outputTexture.write(half4(source), gid);
        return;
    }

    const float luminance = c7CLAHELuminance(straightColor);
    if (luminance <= 1.0e-6f) {
        outputTexture.write(half4(source), gid);
        return;
    }
    const uint bin = min(uint(luminance * 255.0f + 0.5f), C7CLAHEHistogramBinCount - 1u);

    const float tileX = ((float(gid.x) + 0.5f) * float(columns) / float(textureSize.x)) - 0.5f;
    const float tileY = ((float(gid.y) + 0.5f) * float(rows) / float(textureSize.y)) - 0.5f;
    const int leftColumn = tileX <= 0.0f
        ? 0
        : min(int(floor(tileX)), int(columns) - 1);
    const int topRow = tileY <= 0.0f
        ? 0
        : min(int(floor(tileY)), int(rows) - 1);
    const int rightColumn = tileX <= 0.0f
        ? 0
        : (tileX >= float(columns - 1u) ? int(columns) - 1 : leftColumn + 1);
    const int bottomRow = tileY <= 0.0f
        ? 0
        : (tileY >= float(rows - 1u) ? int(rows) - 1 : topRow + 1);
    const float horizontalWeight = leftColumn == rightColumn
        ? 0.0f
        : clamp(tileX - floor(tileX), 0.0f, 1.0f);
    const float verticalWeight = topRow == bottomRow
        ? 0.0f
        : clamp(tileY - floor(tileY), 0.0f, 1.0f);

    const uint topLeft = (uint(topRow) * columns + uint(leftColumn)) * C7CLAHEHistogramBinCount + bin;
    const uint topRight = (uint(topRow) * columns + uint(rightColumn)) * C7CLAHEHistogramBinCount + bin;
    const uint bottomLeft = (uint(bottomRow) * columns + uint(leftColumn)) * C7CLAHEHistogramBinCount + bin;
    const uint bottomRight = (uint(bottomRow) * columns + uint(rightColumn)) * C7CLAHEHistogramBinCount + bin;
    const float top = mix(lookupTable[topLeft], lookupTable[topRight], horizontalWeight);
    const float bottom = mix(lookupTable[bottomLeft], lookupTable[bottomRight], horizontalWeight);
    const float mappedLuminance = mix(top, bottom, verticalWeight);
    const float3 result = clamp(straightColor * (mappedLuminance / luminance), 0.0f, 1.0f);
    outputTexture.write(half4(half3(result * source.a), half(source.a)), gid);
}
