//
//  C7Glitch.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Glitch(texture2d<half, access::write> outputTexture [[texture(0)]],
                     texture2d<half, access::sample> inputTexture [[texture(1)]],
                     constant float *progressPointer [[buffer(0)]],
                     constant float *maxJitterPointer [[buffer(1)]],
                     uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 inColor = inputTexture.read(grid);
    const float x = float(grid.x) / outputTexture.get_width();
    const float y = float(grid.y) / outputTexture.get_height();
    
    const half progress = half(*progressPointer) * 2.0h;
    const half maxJitter = half(*maxJitterPointer);
    
    const half colorROffset = 0.01h;
    const half colorBOffset = -0.025h;
    const float PI = 3.14159265358979323846264338327950288;
    const float amplitude = max(sin(PI / progress), 0.0);
    const float jitter = fract(sin(y) * 43758.5453123) * 2.0 - 1.0;
    const bool needOffset = abs(jitter) < maxJitter * amplitude;
    const float textureX = x + (needOffset ? jitter : (jitter * amplitude * 0.006));
    const float2 textureCoords = float2(textureX, y);
    
    const half4 maskR = inputTexture.sample(quadSampler, textureCoords + float2(colorROffset * amplitude, 0.0));
    const half4 maskB = inputTexture.sample(quadSampler, textureCoords + float2(colorBOffset * amplitude, 0.0));
    
    const half4 outColor = half4(maskR.r, inColor.g, maskB.b, inColor.a);
    outputTexture.write(outColor, grid);
}
