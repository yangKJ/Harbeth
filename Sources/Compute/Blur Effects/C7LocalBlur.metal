//
//  C7LocalBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7LocalBlurPass(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *radius [[buffer(0)]],
                        constant float *horizontal [[buffer(1)]],
                        constant float *weights [[buffer(2)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const int width = inputTexture.get_width();
    const int height = inputTexture.get_height();
    const int x = int(grid.x);
    const int y = int(grid.y);
    
    if (!isfinite(*radius)) { outputTexture.write(inputTexture.read(grid), grid); return; }
    int kernelRadius = int(ceil(clamp(*radius, 0.0f, 100.0f)));
    if (kernelRadius == 0) { outputTexture.write(inputTexture.read(grid), grid); return; }
    
    float4 blurredColor = float4(0.0);
    float weightSum = 0.0;
    
    for (int i = -kernelRadius; i <= kernelRadius; i++) {
            int pixelX = clamp(x + (int(*horizontal) != 0 ? i : 0), 0, width - 1);
            int pixelY = clamp(y + (int(*horizontal) == 0 ? i : 0), 0, height - 1);
            int index = i + kernelRadius;
            float weight = weights[index];
            blurredColor += float4(inputTexture.read(uint2(pixelX, pixelY))) * weight;
            weightSum += weight;
    }
    
    outputTexture.write(half4(blurredColor / weightSum), grid);
}

kernel void C7LocalBlurComposite(texture2d<float, access::write> outputTexture [[texture(0)]], texture2d<float, access::read> inputTexture [[texture(1)]], texture2d<float, access::read> blurredTexture [[texture(2)]], constant float *radius [[buffer(0)]], constant float *centerX [[buffer(1)]], constant float *centerY [[buffer(2)]], constant float *size [[buffer(3)]], constant float *softness [[buffer(4)]], constant float4 *regionContext [[buffer(30)]], uint2 grid [[thread_position_in_grid]]) {
    float4 region = regionContext[1];
    float2 p = (float2(grid) + region.xy) / max(region.zw, float2(1));
    float d = length(p - float2(*centerX, *centerY));
    float4 original = float4(inputTexture.read(grid));
    if (!isfinite(*centerX) || !isfinite(*centerY) || !isfinite(*size) || !isfinite(*softness)) {
        outputTexture.write(original, grid); return;
    }
    float strength = *softness <= 0 ? (d <= *size * 0.5f ? 1.0f : 0.0f)
        : clamp(smoothstep(*size * 0.5, *size * 0.5 - *softness, d), 0.0, 1.0);
    if (strength < 0.01f) { outputTexture.write(original, grid); return; }
    outputTexture.write(mix(original, float4(blurredTexture.read(grid)), strength), grid);
}


// 小作用区保留直接二维路径，避免额外全图 pass 与编码开销。
kernel void C7LocalBlurDirect(texture2d<float, access::write> out [[texture(0)]],
    texture2d<float, access::read> source [[texture(1)]], constant float &radius [[buffer(0)]],
    constant float &centerX [[buffer(1)]], constant float &centerY [[buffer(2)]],
    constant float &size [[buffer(3)]], constant float &softness [[buffer(4)]],
    constant float4 *regionContext [[buffer(30)]], uint2 q [[thread_position_in_grid]]) {
    if (q.x >= out.get_width() || q.y >= out.get_height()) return;
    float4 original = source.read(q);
    if (radius <= 0 || !isfinite(centerX) || !isfinite(centerY) || !isfinite(size) || !isfinite(softness)) { out.write(original, q); return; }
    float4 region = regionContext[1];
    float2 point = (float2(q) + region.xy) / max(region.zw, float2(1));
    float delta = distance(point, float2(centerX, centerY));
    float strength = softness <= 0 ? (delta <= size * 0.5f ? 1.0f : 0.0f) : clamp(smoothstep(size * 0.5f, size * 0.5f - softness, delta), 0.0f, 1.0f);
    if (strength < 0.01f) { out.write(original, q); return; }
    int r = int(ceil(radius));
    float denominator = 2 * (radius / 3) * (radius / 3);
    float4 sum = 0; float total = 0;
    int2 extent = int2(source.get_width(), source.get_height());
    for (int dy = -r; dy <= r; ++dy) {
        for (int dx = -r; dx <= r; ++dx) {
            float weight = exp(-float(dx * dx + dy * dy) / denominator);
            sum += source.read(uint2(clamp(int2(q) + int2(dx, dy), int2(0), extent - 1))) * weight;
            total += weight;
        }
    }
    out.write(mix(original, sum / total, strength), q);
}
