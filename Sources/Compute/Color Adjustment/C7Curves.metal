//
//  C7Curves.metal
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

#include <metal_stdlib>
using namespace metal;

// 曲线插值函数 - 使用Catmull-Rom样条曲线实现平滑插值
float curveInterpolation(float value, constant float* points, int pointCount) {
    if (pointCount == 0) return value;
    if (pointCount == 1) return points[1];
    if (pointCount == 2) {
        // 只有两个点，使用线性插值
        float x0 = points[0];
        float y0 = points[1];
        float x1 = points[2];
        float y1 = points[3];
        float t = (value - x0) / (x1 - x0);
        return mix(y0, y1, t);
    }
    
    // 找到value所在的区间
    int i = 0;
    while (i < pointCount - 1 && points[i * 2] < value) {
        i++;
    }
    
    // 处理边界情况
    if (i == 0) return points[1];
    if (i == pointCount - 1) return points[(pointCount - 1) * 2 + 1];
    
    // 准备Catmull-Rom样条曲线的控制点
    int i0 = max(0, i - 1);
    int i1 = i;
    int i2 = min(i + 1, pointCount - 1);
    int i3 = min(i + 2, pointCount - 1);
    
    float x0 = points[i0 * 2];
    float y0 = points[i0 * 2 + 1];
    float x1 = points[i1 * 2];
    float y1 = points[i1 * 2 + 1];
    float x2 = points[i2 * 2];
    float y2 = points[i2 * 2 + 1];
    float x3 = points[i3 * 2];
    float y3 = points[i3 * 2 + 1];
    
    // 计算参数t（在x1到x2之间的归一化值）
    float t = (value - x1) / (x2 - x1);
    t = clamp(t, 0.0, 1.0);
    
    // 计算Catmull-Rom样条曲线的系数，考虑x值的分布
    float d1 = x1 - x0;
    float d2 = x2 - x1;
    float d3 = x3 - x2;
    
    // 计算张力参数
    float tension = 0.5;
    
    // 计算控制点
    float c1 = y1 + tension * d2 * (y2 - y0) / (d1 + d2);
    float c2 = y2 - tension * d2 * (y3 - y1) / (d2 + d3);
    
    // 使用三次贝塞尔曲线插值
    float t2 = t * t;
    float t3 = t2 * t;
    
    float a = 2.0 * t3 - 3.0 * t2 + 1.0;
    float b = -2.0 * t3 + 3.0 * t2;
    float c = t3 - 2.0 * t2 + t;
    float d = t3 - t2;
    
    return a * y1 + b * y2 + c * c1 + d * c2;
}

kernel void C7Curves(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::read> inputTexture [[texture(1)]],
                     constant float *rgbCount [[buffer(0)]],
                     constant float *redCount [[buffer(1)]],
                     constant float *greenCount [[buffer(2)]],
                     constant float *blueCount [[buffer(3)]],
                     constant float *rgbPoints [[buffer(4)]],
                     constant float *redPoints [[buffer(5)]],
                     constant float *greenPoints [[buffer(6)]],
                     constant float *bluePoints [[buffer(7)]],
                     uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    // 解析点数量
    int rgbPointCount = int(*rgbCount);
    int redPointCount = int(*redCount);
    int greenPointCount = int(*greenCount);
    int bluePointCount = int(*blueCount);
    
    // 计算RGB曲线调整
    float gray = 0.299 * float(inColor.r) + 0.587 * float(inColor.g) + 0.114 * float(inColor.b);
    float rgbAdjustment = curveInterpolation(gray, rgbPoints, rgbPointCount);
    
    // 计算各通道曲线调整
    float redAdjustment = curveInterpolation(float(inColor.r), redPoints, redPointCount);
    float greenAdjustment = curveInterpolation(float(inColor.g), greenPoints, greenPointCount);
    float blueAdjustment = curveInterpolation(float(inColor.b), bluePoints, bluePointCount);
    
    // 应用调整
    half4 outColor;
    outColor.r = half(redAdjustment);
    outColor.g = half(greenAdjustment);
    outColor.b = half(blueAdjustment);
    outColor.a = inColor.a;
    
    outputTexture.write(outColor, grid);
}
