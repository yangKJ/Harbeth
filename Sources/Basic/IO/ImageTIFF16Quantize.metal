//
//  ImageTIFF16Quantize.metal
//  Harbeth
//
//  Created by Condy on 2026/11/9.
//

#include <metal_stdlib>
using namespace metal;

kernel void imageTIFF16Quantize(texture2d<float, access::read> source [[texture(0)]],
                                device ushort4 *pixels [[buffer(0)]],
                                uint2 position [[thread_position_in_grid]]) {
    if (position.x >= source.get_width() || position.y >= source.get_height()) { return; }
    const float4 value = clamp(source.read(position), 0.0f, 1.0f);
    pixels[position.y * source.get_width() + position.x] = ushort4(round(value * 65535.0f));
}
