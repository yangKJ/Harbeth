//
//  C7EdgeGlow.metal
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7EdgeGlow(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::sample> inputTexture [[texture(1)]],
                       constant float *timePointer [[buffer(0)]],
                       constant float *spacingPointer [[buffer(1)]],
                       constant float4 *vectorColor [[buffer(2)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float w = outputTexture.get_width();
    const float h = outputTexture.get_height();
    const float2 textureCoordinate = float2(grid) / float2(w, h);
    const float x = textureCoordinate.x;
    const float y = textureCoordinate.y;
    const half spacing = half(*spacingPointer);
    
    // 边缘检测矩阵卷积核
    const half3x3 matrix = half3x3({-1.0, -1.0, -1.0}, {-1.0,  8.0, -1.0}, {-1.0, -1.0, -1.0});
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    half4 result = half4(0.0h);
    for (int i = 0; i < 9; i++) {
        int a = i % 3; int b = i / 3;
        const half4 sample = inputTexture.sample(quadSampler, float2(x + (a - 3/2.0) / w, y + (b - 3/2.0) / h));
        result += sample * matrix[a][b];
    }
    
    // 向量长度比`spacing`小的数据显示原本颜色，非边缘
    if (length(result) <= spacing) {
        outputTexture.write(inColor, grid);
        return;
    }
    
    const half time = half(*timePointer);
    const half4 lineColor = half4(*vectorColor);
    
    const half4 outColor = half4(lineColor * sin(time * 5.0h) + inColor * cos(time * 5.0h));
    outputTexture.write(outColor, grid);
}
