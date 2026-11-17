// 由 Condy 维护。空间卷积直接使用有符号像素坐标。
#include <metal_stdlib>
using namespace metal;
kernel void C7ConvolutionMatrix3x3(texture2d<float, access::write> outputTexture [[texture(0)]],
                                   texture2d<float, access::read> inputTexture [[texture(1)]],
                                   constant float &intensity [[buffer(0)]],
                                   constant float &pixel [[buffer(1)]],
                                   constant float3x3 &matrix [[buffer(2)]],
                                   constant float &halfOutput [[buffer(3)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 center = inputTexture.read(grid);
    float4 result = center;
    if (isfinite(intensity) && intensity > 0.0f) {
        const int2 maximum = int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1);
        const float bound = float(max(maximum.x, maximum.y));
        const int step = isfinite(pixel) ? int(clamp(pixel, -bound, bound)) : 0;
        float3 sum = float3(0.0f);
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                const int2 point = clamp(int2(grid) + int2(x,y) * step, int2(0), maximum);
                sum += inputTexture.read(uint2(point)).rgb * matrix[y + 1][x + 1];
            }
        }
        result.rgb = mix(center.rgb, sum, clamp(intensity, 0.0f, 1.0f));
    }
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
