//
//  C7AffineTransform.metal
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

#include <metal_stdlib>
using namespace metal;

namespace transform {
    METAL_FUNC bool zeroOrOne(float x) {
        if (abs(x - round(x)) >= 1e-10) { return false; }
        float a = abs(round(x));
        return a == 0 || a == 1;
    }
}

kernel void C7AffineTransform(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::sample> inputTexture [[texture(1)]],
                              constant float *anchorPointX [[buffer(0)]],
                              constant float *anchorPointY [[buffer(1)]],
                              constant float3x2 *transformMatrix [[buffer(2)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const float3x2 matrix = *transformMatrix;
    const float a = matrix[0][0], b = matrix[0][1];
    const float c = matrix[1][0], d = matrix[1][1];
    const float w = inputTexture.get_width();
    const float h = inputTexture.get_height();
    const float anchorX = (*anchorPointX);
    const float anchorY = (*anchorPointY);
    
    if (a * d - b * c == 0) {
        outputTexture.write(half4(0), grid);
        return;
    }
    
    const float outX = grid.x - outputTexture.get_width() * anchorX;
    const float outY = grid.y - outputTexture.get_height() * anchorY;
    
    const float tx = matrix[2][0], ty = matrix[2][1];
    
    const float inX = (d * outX - c * outY - d * tx + c * ty) / (a * d - b * c) / w + anchorX;
    const float inY = (b * outX - a * outY - b * tx + a * ty) / (b * c - a * d) / h + anchorY;
    
    // Set empty pixel when out of range
    if (inX * w < -1 || inX * w > w + 1 || inY * h < -1 || inY * h > h + 1) {
        outputTexture.write(half4(0), grid);
        return;
    }
    
    #if defined(__HAVE_BICUBIC_FILTERING__)
    // If rotation angle is 90 * N degrees (N is integer), use bicubic
    if (transform::zeroOrOne(a) &&
        transform::zeroOrOne(b) &&
        transform::zeroOrOne(c) &&
        transform::zeroOrOne(d)) {
        constexpr sampler quadSampler(mag_filter::bicubic, min_filter::bicubic);
        const half4 color = inputTexture.sample(quadSampler, float2(inX, inY));
        outputTexture.write(color, grid);
        return;
    }
    #endif
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inputTexture.sample(quadSampler, float2(inX, inY));
    outputTexture.write(outColor, grid);
}
