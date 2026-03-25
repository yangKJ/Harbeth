//
//  C7Curves.metal
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

#include <metal_stdlib>
using namespace metal;

float curveInterpolation(float value, constant float* points, int pointCount) {
    if (pointCount == 0) return value;
    if (pointCount == 1) return points[1];
    if (pointCount == 2) {
        float x0 = points[0];
        float y0 = points[1];
        float x1 = points[2];
        float y1 = points[3];
        if (x1 == x0) return y0;
        float t = (value - x0) / (x1 - x0);
        t = clamp(t, 0.0, 1.0);
        return mix(y0, y1, t);
    }
    
    int i = 0;
    while (i < pointCount - 1 && points[i * 2] < value) {
        i++;
    }
    
    if (i == 0) {
        float x0 = points[0];
        float y0 = points[1];
        float x1 = points[2];
        float y1 = points[3];
        if (x1 == x0) return y0;
        float t = (value - x0) / (x1 - x0);
        return mix(y0, y1, t);
    }
    if (i == pointCount - 1) {
        float x0 = points[(pointCount - 2) * 2];
        float y0 = points[(pointCount - 2) * 2 + 1];
        float x1 = points[(pointCount - 1) * 2];
        float y1 = points[(pointCount - 1) * 2 + 1];
        if (x1 == x0) return y0;
        float t = (value - x0) / (x1 - x0);
        return mix(y0, y1, t);
    }
    
    float x0 = points[i * 2];
    float y0 = points[i * 2 + 1];
    float x1 = points[(i + 1) * 2];
    float y1 = points[(i + 1) * 2 + 1];
    if (x1 == x0) return y0;
    float t = (value - x0) / (x1 - x0);
    return mix(y0, y1, t);
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
    
    int rgbPointCount = int(*rgbCount);
    int redPointCount = int(*redCount);
    int greenPointCount = int(*greenCount);
    int bluePointCount = int(*blueCount);
    
    float red = float(inColor.r);
    float green = float(inColor.g);
    float blue = float(inColor.b);
    
    if (rgbPointCount >= 2) {
        red = curveInterpolation(red, rgbPoints, rgbPointCount);
        green = curveInterpolation(green, rgbPoints, rgbPointCount);
        blue = curveInterpolation(blue, rgbPoints, rgbPointCount);
    }
    
    if (redPointCount >= 2) {
        red = curveInterpolation(red, redPoints, redPointCount);
    }
    if (greenPointCount >= 2) {
        green = curveInterpolation(green, greenPoints, greenPointCount);
    }
    if (bluePointCount >= 2) {
        blue = curveInterpolation(blue, bluePoints, bluePointCount);
    }
    
    half4 outColor;
    outColor.r = half(red);
    outColor.g = half(green);
    outColor.b = half(blue);
    outColor.a = inColor.a;
    
    outputTexture.write(outColor, grid);
}
