//
//  C7Vignette.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Vignette(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant float *centerX [[buffer(0)]],
                       constant float *centerY [[buffer(1)]],
                       constant float *colorR [[buffer(2)]],
                       constant float *colorG [[buffer(3)]],
                       constant float *colorB [[buffer(4)]],
                       constant float *start [[buffer(5)]],
                       constant float *end [[buffer(6)]],
                       uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float2 textureCoordinate = float2(float(grid.x) / outputTexture.get_width(), float(grid.y) / outputTexture.get_height());
    
    const half2 center = half2(*centerX, *centerY);
    const half3 color = half3(*colorR, *colorG, *colorB);
    const float dd = distance(textureCoordinate, float2(center));
    const half percent = smoothstep(*start, *end, dd);
    const half4 outColor = half4(mix(inColor.rgb, color, percent), inColor.a);
    
    outputTexture.write(outColor, grid);
}
