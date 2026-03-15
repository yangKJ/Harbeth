//
//  C7Kuwahara.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Kuwahara(texture2d<float, access::write> outTexture [[texture(0)]],
                       texture2d<float, access::read> inTexture [[texture(1)]],
                       constant float *radius [[buffer(0)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const int radiusValue = int(radius[0]);
    const int2 size = int2(inTexture.get_width(), inTexture.get_height());
    
    if (int(grid.x) >= size.x || int(grid.y) >= size.y) {
        return;
    }
    
    // Calculate texture coordinates
    float2 uv = float2(float(grid.x) / float(size.x), float(grid.y) / float(size.y));
    float2 src_size = float2(1.0 / float(size.x), 1.0 / float(size.y));
    
    // Calculate number of pixels in each region
    float n = float((radiusValue + 1) * (radiusValue + 1));
    
    // Initialize region sums and sum of squares
    float4 m0 = float4(0.0, 0.0, 0.0, 0.0);
    float4 m1 = float4(0.0, 0.0, 0.0, 0.0);
    float4 m2 = float4(0.0, 0.0, 0.0, 0.0);
    float4 m3 = float4(0.0, 0.0, 0.0, 0.0);
    
    float4 s0 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s1 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s2 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s3 = float4(0.0, 0.0, 0.0, 0.0);
    
    // Process top-left region
    for (int j = -radiusValue; j <= 0; ++j) {
        for (int i = -radiusValue; i <= 0; ++i) {
            float2 texCoord = uv + float2(float(i), float(j)) * src_size;
            // Clamp texture coordinates to [0, 1]
            texCoord = clamp(texCoord, float2(0.0), float2(1.0));
            // Convert to pixel coordinates
            uint2 pixelCoord = uint2(texCoord.x * float(size.x), texCoord.y * float(size.y));
            // Clamp pixel coordinates to texture bounds
            pixelCoord = clamp(pixelCoord, uint2(0, 0), uint2(size.x - 1, size.y - 1));
            float4 c = inTexture.read(pixelCoord);
            m0 += c;
            s0 += c * c;
        }
    }
    
    // Process top-right region
    for (int j = -radiusValue; j <= 0; ++j) {
        for (int i = 0; i <= radiusValue; ++i) {
            float2 texCoord = uv + float2(float(i), float(j)) * src_size;
            texCoord = clamp(texCoord, float2(0.0), float2(1.0));
            uint2 pixelCoord = uint2(texCoord.x * float(size.x), texCoord.y * float(size.y));
            pixelCoord = clamp(pixelCoord, uint2(0, 0), uint2(size.x - 1, size.y - 1));
            float4 c = inTexture.read(pixelCoord);
            m1 += c;
            s1 += c * c;
        }
    }
    
    // Process bottom-right region
    for (int j = 0; j <= radiusValue; ++j) {
        for (int i = 0; i <= radiusValue; ++i) {
            float2 texCoord = uv + float2(float(i), float(j)) * src_size;
            texCoord = clamp(texCoord, float2(0.0), float2(1.0));
            uint2 pixelCoord = uint2(texCoord.x * float(size.x), texCoord.y * float(size.y));
            pixelCoord = clamp(pixelCoord, uint2(0, 0), uint2(size.x - 1, size.y - 1));
            float4 c = inTexture.read(pixelCoord);
            m2 += c;
            s2 += c * c;
        }
    }
    
    // Process bottom-left region
    for (int j = 0; j <= radiusValue; ++j) {
        for (int i = -radiusValue; i <= 0; ++i) {
            float2 texCoord = uv + float2(float(i), float(j)) * src_size;
            texCoord = clamp(texCoord, float2(0.0), float2(1.0));
            uint2 pixelCoord = uint2(texCoord.x * float(size.x), texCoord.y * float(size.y));
            pixelCoord = clamp(pixelCoord, uint2(0, 0), uint2(size.x - 1, size.y - 1));
            float4 c = inTexture.read(pixelCoord);
            m3 += c;
            s3 += c * c;
        }
    }
    
    // Calculate variances and find minimum
    float min_sigma2 = 1e+2;
    float4 resultColor = float4(0.0, 0.0, 0.0, 1.0);
    
    // Process top-left region
    m0 /= n;
    s0 = abs(s0 / n - m0 * m0);
    float sigma2 = s0.r + s0.g + s0.b;
    if (sigma2 < min_sigma2) {
        min_sigma2 = sigma2;
        resultColor = m0;
    }
    
    // Process top-right region
    m1 /= n;
    s1 = abs(s1 / n - m1 * m1);
    sigma2 = s1.r + s1.g + s1.b;
    if (sigma2 < min_sigma2) {
        min_sigma2 = sigma2;
        resultColor = m1;
    }
    
    // Process bottom-right region
    m2 /= n;
    s2 = abs(s2 / n - m2 * m2);
    sigma2 = s2.r + s2.g + s2.b;
    if (sigma2 < min_sigma2) {
        min_sigma2 = sigma2;
        resultColor = m2;
    }
    
    // Process bottom-left region
    m3 /= n;
    s3 = abs(s3 / n - m3 * m3);
    sigma2 = s3.r + s3.g + s3.b;
    if (sigma2 < min_sigma2) {
        min_sigma2 = sigma2;
        resultColor = m3;
    }
    
    // Write the result
    outTexture.write(resultColor, grid);
}
