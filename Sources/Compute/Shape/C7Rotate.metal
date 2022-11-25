//
//  C7Rotate.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Rotate(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::sample> inputTexture [[texture(1)]],
                     constant float *angle [[buffer(0)]],
                     uint2 grid [[thread_position_in_grid]]) {
    const float outX = float(grid.x) - outputTexture.get_width() / 2.0f;
    const float outY = float(grid.y) - outputTexture.get_height() / 2.0f;
    const float dd = distance(float2(outX, outY), float2(0, 0));
    const float pi = 3.14159265358979323846264338327950288;
    const float w = inputTexture.get_width();
    const float h = inputTexture.get_height();
    float outAngle = atan(outY / outX);
    if (outX < 0) { outAngle += pi; };
    const float inAngle = outAngle - float(*angle);
    const float inX = (cos(inAngle) * dd + w / 2.0f) / w;
    const float inY = (sin(inAngle) * dd + h / 2.0f) / h;
    
    // Set empty pixel when out of range
    if (inX * w < -1 || inX * w > w + 1 || inY * h < -1 || inY * h > h + 1) {
        outputTexture.write(half4(0), grid);
        return;
    }
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 outColor = inputTexture.sample(quadSampler, float2(inX, inY));
    outputTexture.write(outColor, grid);
}
