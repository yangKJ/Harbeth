//
//  C7DiffractionCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

#include <metal_stdlib>
using namespace metal;

static half4 readClampedPixel(texture2d<half, access::read> texture, int2 coordinate) {
    int2 clamped = int2(
        clamp(coordinate.x, 0, int(texture.get_width()) - 1),
        clamp(coordinate.y, 0, int(texture.get_height()) - 1)
    );
    return texture.read(uint2(clamped));
}

kernel void C7DiffractionCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> inputTexture [[texture(1)]],
                                    constant float *amount [[buffer(0)]],
                                    constant float *radius [[buffer(1)]],
                                    constant float *edgeThreshold [[buffer(2)]],
                                    uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    int offset = int(round(clamp(*radius, 1.0f, 2.0f)));
    int2 coordinate = int2(grid);

    half4 center = inputTexture.read(grid);
    half4 north = readClampedPixel(inputTexture, coordinate + int2(0, -offset));
    half4 south = readClampedPixel(inputTexture, coordinate + int2(0, offset));
    half4 west  = readClampedPixel(inputTexture, coordinate + int2(-offset, 0));
    half4 east  = readClampedPixel(inputTexture, coordinate + int2(offset, 0));
    half4 northwest = readClampedPixel(inputTexture, coordinate + int2(-offset, -offset));
    half4 northeast = readClampedPixel(inputTexture, coordinate + int2(offset, -offset));
    half4 southwest = readClampedPixel(inputTexture, coordinate + int2(-offset, offset));
    half4 southeast = readClampedPixel(inputTexture, coordinate + int2(offset, offset));

    half4 blur = (center * 4.0h + north + south + west + east + northwest + northeast + southwest + southeast) / 12.0h;
    half3 highPass = center.rgb - blur.rgb;

    half edgeStrength = dot(abs(highPass), half3(0.299h, 0.587h, 0.114h));
    half edgeMask = smoothstep(half(*edgeThreshold), max(half(*edgeThreshold) * 3.0h, half(*edgeThreshold) + 0.0001h), edgeStrength);

    half3 corrected = center.rgb + highPass * half(*amount) * edgeMask;
    outputTexture.write(half4(clamp(corrected, half3(0.0h), half3(1.0h)), center.a), grid);
}
