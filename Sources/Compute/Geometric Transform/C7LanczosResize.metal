//
//  C7LanczosResize.metal
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

#include <metal_stdlib>
using namespace metal;

namespace lanczos {
    float weight(float x) {
        x = fabs(x);
        if (x < 1e-5f) return 1.0f;
        if (x >= 3.0f) return 0.0f;
        const float p = M_PI_F * x;
        return (sin(p) / p) * (sin(p / 3.0f) / (p / 3.0f));
    }
    float4 finish(float4 color) {
        // 负瓣允许扩展范围颜色；仅约束覆盖并同步关联颜色，不能把 HDR 夹回 SDR。
        const float alpha = clamp(color.a, 0.0f, 1.0f);
        if (alpha <= 0.0f) return float4(0.0f);
        return float4(color.rgb * (alpha / color.a), alpha);
    }
    float4 store(float4 color, float halfOutput) {
        return halfOutput > 0.5f ? float4(half4(color)) : color;
    }
}

kernel void C7LanczosResize(texture2d<float, access::write> output [[texture(0)]],
                            texture2d<float, access::read> input [[texture(1)]],
                            constant float &halfOutput [[buffer(0)]],
                            uint2 p [[thread_position_in_grid]]) {
    const uint2 inSize(input.get_width(), input.get_height()), outSize(output.get_width(), output.get_height());
    if (any(p >= outSize)) return;
    if (all(inSize == outSize)) {
        output.write(lanczos::store(input.read(p), halfOutput), p); return;
    }
    const float2 scale = float2(inSize) / float2(outSize);
    const float2 supportScale = max(scale, 1.0f);
    const float2 source = (float2(p) + 0.5f) * scale - 0.5f;
    const int2 first = int2(floor(source - 3.0f * supportScale)) + 1;
    const int2 last = int2(ceil(source + 3.0f * supportScale)) - 1;
    float4 color(0.0f);
    float sum = 0.0f;
    for (int y = first.y; y <= last.y; ++y) {
        const float wy = lanczos::weight((source.y - float(y)) / supportScale.y);
        if (wy == 0.0f) continue;
        for (int x = first.x; x <= last.x; ++x) {
            const float w = wy * lanczos::weight((source.x - float(x)) / supportScale.x);
            if (w == 0.0f) continue;
            // 权重使用未夹边的 tap 坐标；只有纹理读取采用边缘延拓。
            const uint2 q = uint2(clamp(int2(x, y), int2(0), int2(inSize) - 1));
            color += input.read(q) * w;
            sum += w;
        }
    }
    color = fabs(sum) > 1e-8f ? color / sum : input.read(uint2(clamp(int2(round(source)), int2(0), int2(inSize) - 1)));
    output.write(lanczos::store(lanczos::finish(color), halfOutput), p);
}

// 同一 L3 方程的可分离执行；中间表面保持 Float32，最终 pass 才处理覆盖及量化。
kernel void HarbethLanczosAxis(texture2d<float, access::write> output [[texture(0)]],
                              texture2d<float, access::read> input [[texture(1)]],
                              constant uint &axis [[buffer(0)]],
                              constant float &halfOutput [[buffer(1)]],
                              constant uint &finalPass [[buffer(2)]],
                              uint2 p [[thread_position_in_grid]]) {
    const uint2 inSize(input.get_width(), input.get_height()), outSize(output.get_width(), output.get_height());
    if (any(p >= outSize)) return;
    float4 color;
    if (inSize[axis] == outSize[axis]) {
        color = input.read(p);
    } else {
        const float scale = float(inSize[axis]) / float(outSize[axis]);
        const float supportScale = max(scale, 1.0f);
        const float source = (float(p[axis]) + 0.5f) * scale - 0.5f;
        const int first = int(floor(source - 3.0f * supportScale)) + 1;
        const int last = int(ceil(source + 3.0f * supportScale)) - 1;
        color = float4(0.0f);
        float sum = 0.0f;
        for (int tap = first; tap <= last; ++tap) {
            const float w = lanczos::weight((source - float(tap)) / supportScale);
            if (w == 0.0f) continue;
            uint2 q = p;
            q[axis] = uint(clamp(tap, 0, int(inSize[axis]) - 1));
            color += input.read(q) * w;
            sum += w;
        }
        uint2 nearest = p;
        nearest[axis] = uint(clamp(int(round(source)), 0, int(inSize[axis]) - 1));
        color = fabs(sum) > 1e-8f ? color / sum : input.read(nearest);
    }
    if (finalPass != 0) color = lanczos::finish(color);
    output.write(lanczos::store(color, halfOutput), p);
}
