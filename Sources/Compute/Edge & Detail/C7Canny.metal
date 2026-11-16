//
//  C7Canny.metal
//  Harbeth
//
//  Created by Condy on 2026/2/7.
//

#include <metal_stdlib>
using namespace metal;

// MPSImageCanny 已完成梯度、非极大值抑制和完整 8 邻域滞后连接；此 pass 只统一输出为灰度 RGB + opaque alpha。
kernel void C7CannyFinal(texture2d<half, access::write> outputTexture [[texture(0)]], texture2d<half, access::read> inputTexture [[texture(1)]], texture2d<half, access::read> edges [[texture(2)]], uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= inputTexture.get_width() || grid.y >= inputTexture.get_height()) return;
    half value = edges.read(grid).r;
    outputTexture.write(half4(value, value, value, 1.0h), grid);
}
