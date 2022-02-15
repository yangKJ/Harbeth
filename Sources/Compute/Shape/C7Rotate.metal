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
    float outAngle = atan(outY / outX);
    if (outX < 0) { outAngle += pi; };
    const float inAngle = outAngle - float(*angle);
    const float inX = (cos(inAngle) * dd + inputTexture.get_width() / 2.0f) / inputTexture.get_width();
    const float inY = (sin(inAngle) * dd + inputTexture.get_height() / 2.0f) / inputTexture.get_height();
    
    // Set empty pixel when out of range
    if (inX * inputTexture.get_width() < -1 ||
        inX * inputTexture.get_width() > inputTexture.get_width() + 1 ||
        inY * inputTexture.get_height() < -1 ||
        inY * inputTexture.get_height() > inputTexture.get_height() + 1) {
        outputTexture.write(half4(0), grid);
        return;
    }
    
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 color = inputTexture.sample(quadSampler, float2(inX, inY));
    outputTexture.write(color, grid);
}
