//
//  C7WaterRipple.metal
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7WaterRipple(texture2d<half, access::write> outputTexture [[texture(0)]],
                          texture2d<half, access::sample> inputTexture [[texture(1)]],
                          constant float *centerX [[buffer(0)]],
                          constant float *centerY [[buffer(1)]],
                          constant float *ripplex [[buffer(2)]],
                          constant float *boundary [[buffer(3)]],
                          uint2 grid [[thread_position_in_grid]]) {
    float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    const half ripple = half(*ripplex);
    const float2 touchXY = float2(*centerX, *centerY);
    float dis = distance(textureCoordinate, touchXY);// 采样点坐标与中心点的距离
    
    if ((ripple - *boundary) > 0.0 && (dis <= (ripple + *boundary)) && (dis >= (ripple - *boundary))) {
        float moveDis = -pow(8 * (dis - ripple), 3.0);// 平滑函数 -(8x)^3 采样坐标移动距离
        float2 unitDirectionVec = normalize(textureCoordinate - touchXY);// 单位方向向量
        textureCoordinate = textureCoordinate + (unitDirectionVec * moveDis);// 采样坐标偏移（实现放大和缩小效果）
    }
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inputTexture.sample(quadSampler, textureCoordinate);
    
    outputTexture.write(outColor, grid);
}
