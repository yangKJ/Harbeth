//
//  C7Canny.metal
//  Harbeth
//
//  Created by Condy on 2026/2/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Canny(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *threshold1 [[buffer(0)]],
                    constant float *threshold2 [[buffer(1)]],
                    uint2 grid [[thread_position_in_grid]]) {
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();
    
    if (grid.x >= width || grid.y >= height) {
        return;
    }
    
    constexpr float sobelX[9] = {
        -1.0, 0.0, 1.0,
        -2.0, 0.0, 2.0,
        -1.0, 0.0, 1.0
    };
    
    constexpr float sobelY[9] = {
        -1.0, -2.0, -1.0,
        0.0,  0.0,  0.0,
        1.0,  2.0,  1.0
    };
    
    float gx = 0.0;
    float gy = 0.0;
    
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            int x = int(grid.x) + j;
            int y = int(grid.y) + i;
            if (x < 0 || x >= int(width) || y < 0 || y >= int(height)) {
                continue;
            }
            half4 pixel = inputTexture.read(uint2(x, y));
            float luminance = float(pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
            int idx = (i + 1) * 3 + (j + 1);
            gx += luminance * sobelX[idx];
            gy += luminance * sobelY[idx];
        }
    }
    
    float magnitude = sqrt(gx * gx + gy * gy);
    float direction = atan2(gy, gx);
    float edgeStrength = magnitude;
    float angle = direction * 180.0 / M_PI_F;
    if (angle < 0) angle += 180.0;
    float2 offset1, offset2;
    if ((angle >= 0 && angle < 22.5) || (angle >= 157.5 && angle <= 180)) {
        offset1 = float2(1, 0);
        offset2 = float2(-1, 0);
    } else if (angle >= 22.5 && angle < 67.5) {
        offset1 = float2(1, 1);
        offset2 = float2(-1, -1);
    } else if (angle >= 67.5 && angle < 112.5) {
        offset1 = float2(0, 1);
        offset2 = float2(0, -1);
    } else {
        offset1 = float2(-1, 1);
        offset2 = float2(1, -1);
    }
    
    int pos1_x = int(grid.x) + int(offset1.x);
    int pos1_y = int(grid.y) + int(offset1.y);
    int pos2_x = int(grid.x) + int(offset2.x);
    int pos2_y = int(grid.y) + int(offset2.y);
    
    float magnitude1 = 0.0;
    float magnitude2 = 0.0;
    
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            int sampleX = pos1_x + j;
            int sampleY = pos1_y + i;
            if (sampleX < 0 || sampleX >= int(width) || sampleY < 0 || sampleY >= int(height)) {
                continue;
            }
            half4 pixel = inputTexture.read(uint2(sampleX, sampleY));
            float luminance = float(pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
            int idx = (i + 1) * 3 + (j + 1);
            float gx1 = luminance * sobelX[idx];
            float gy1 = luminance * sobelY[idx];
            magnitude1 += sqrt(gx1 * gx1 + gy1 * gy1) / 9.0;
        }
    }
    
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            int sampleX = pos2_x + j;
            int sampleY = pos2_y + i;
            if (sampleX < 0 || sampleX >= int(width) || sampleY < 0 || sampleY >= int(height)) {
                continue;
            }
            half4 pixel = inputTexture.read(uint2(sampleX, sampleY));
            float luminance = float(pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
            int idx = (i + 1) * 3 + (j + 1);
            float gx2 = luminance * sobelX[idx];
            float gy2 = luminance * sobelY[idx];
            magnitude2 += sqrt(gx2 * gx2 + gy2 * gy2) / 9.0;
        }
    }
    
    if (magnitude < magnitude1 || magnitude < magnitude2) {
        edgeStrength = 0.0;
    }
    
    float lowThreshold = *threshold1;
    float highThreshold = *threshold2;
    half4 resultColor;
    if (edgeStrength < lowThreshold) {
        resultColor = half4(0.0, 0.0, 0.0, 1.0);
    } else if (edgeStrength >= highThreshold) {
        resultColor = half4(1.0, 1.0, 1.0, 1.0);
    } else {
        bool hasStrongNeighbor = false;
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                if (i == 0 && j == 0) continue;
                int neighborX = int(grid.x) + j;
                int neighborY = int(grid.y) + i;
                if (neighborX < 0 || neighborX >= int(width) || neighborY < 0 || neighborY >= int(height)) {
                    continue;
                }
                float neighborMagnitude = 0.0;
                for (int m = -1; m <= 1; m++) {
                    for (int n = -1; n <= 1; n++) {
                        int sampleX = neighborX + n;
                        int sampleY = neighborY + m;
                        if (sampleX < 0 || sampleX >= int(width) || sampleY < 0 || sampleY >= int(height)) {
                            continue;
                        }
                        half4 pixel = inputTexture.read(uint2(sampleX, sampleY));
                        float luminance = float(pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
                        int idx = (m + 1) * 3 + (n + 1);
                        float gxn = luminance * sobelX[idx];
                        float gyn = luminance * sobelY[idx];
                        neighborMagnitude += sqrt(gxn * gxn + gyn * gyn) / 9.0;
                    }
                }
                if (neighborMagnitude >= highThreshold) {
                    hasStrongNeighbor = true;
                    break;
                }
            }
            if (hasStrongNeighbor) break;
        }
        resultColor = hasStrongNeighbor ? half4(1.0, 1.0, 1.0, 1.0) : half4(0.0, 0.0, 0.0, 1.0);
    }
    outputTexture.write(resultColor, grid);
}
