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
                       constant float *colorR [[buffer(2)]],
                       constant float *colorG [[buffer(3)]],
                       constant float *colorB [[buffer(4)]],
                       constant float *start [[buffer(5)]],
                       constant float *end [[buffer(6)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const float u_Time = float(*start);
    const float u_Boundary = 0.2;//float(*colorG);
    const float2 center = float2(*centerX, *centerY);
    
    const float ratio = textureCoordinate.y / textureCoordinate.x;
    float2 texCoord = textureCoordinate;// * float2(1.0, ratio);
    float2 touchXY = center;// * float2(1.0, ratio);
    float dis = distance(texCoord, touchXY);//采样点坐标与中心点的距离
    
    if ((u_Time - u_Boundary) > 0.0 && (dis <= (u_Time + u_Boundary)) && (dis >= (u_Time - u_Boundary))) {
        float diff = (dis - u_Time); //输入 diff
        float moveDis = -pow(8 * diff, 3.0);//平滑函数 -(8x)^3 采样坐标移动距离
        float2 unitDirectionVec = normalize(texCoord - touchXY);//单位方向向量
        texCoord = texCoord + (unitDirectionVec * moveDis);//采样坐标偏移（实现放大和缩小效果）
    }
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inputTexture.sample(quadSampler, texCoord);
    
    outputTexture.write(outColor, grid);
}
