//
//  C7Gamma.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Gamma(texture2d<half, access::write> outputTexture [[texture(0)]],
                    texture2d<half, access::read> inputTexture [[texture(1)]],
                    constant float *gamma [[buffer(0)]],
                    uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    // 扩展范围允许负分量；保留符号，避免分数次幂产生NaN。
    const half3 signs = select(half3(1.0h), half3(-1.0h), inColor.rgb < half3(0.0h));
    const half4 outColor = half4(signs * pow(abs(inColor.rgb), half3(*gamma)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
