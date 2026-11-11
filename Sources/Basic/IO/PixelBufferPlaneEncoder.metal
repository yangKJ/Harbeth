//
//  PixelBufferPlaneEncoder.metal
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//
#include <metal_stdlib>
using namespace metal;

struct BiPlanar420Parameters {
    float2 coefficients;
    uint tenBit;
    uint fullRange;
};

static float3 planarYCbCr(float3 rgb, constant BiPlanar420Parameters& p) {
    float kr = p.coefficients.x, kb = p.coefficients.y;
    float y = dot(rgb, float3(kr, 1.0f - kr - kb, kb));
    return float3(y, (rgb.b - y) / (2.0f * (1.0f - kb)), (rgb.r - y) / (2.0f * (1.0f - kr)));
}

static float planarCode(float value, bool chroma, constant BiPlanar420Parameters& p) {
    float maximum = p.tenBit ? 1023.0f : 255.0f;
    float scale = p.fullRange ? maximum : (chroma ? (p.tenBit ? 896.0f : 224.0f) : (p.tenBit ? 876.0f : 219.0f));
    float offset = chroma ? (p.tenBit ? 512.0f : 128.0f) : (p.fullRange ? 0.0f : (p.tenBit ? 64.0f : 16.0f));
    float code = round(clamp(value * scale + offset, 0.0f, maximum));
    // P010将10位有效值置于16位字的高位，不能按普通R16归一化值直接写入。
    return p.tenBit ? code * 64.0f / 65535.0f : code / 255.0f;
}

kernel void HarbethRGBToBiPlanar420(
    texture2d<float, access::read> rgb [[texture(0)]],
    texture2d<float, access::write> yPlane [[texture(1)]],
    texture2d<float, access::write> uvPlane [[texture(2)]],
    constant BiPlanar420Parameters& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= rgb.get_width() || gid.y >= rgb.get_height()) return;
    float3 value = planarYCbCr(rgb.read(gid).rgb, p);
    yPlane.write(float4(planarCode(value.x, false, p)), gid);
    if ((gid.x & 1) || (gid.y & 1)) return;
    float3 average = float3(0);
    for (uint dy = 0; dy < 2; ++dy) {
        for (uint dx = 0; dx < 2; ++dx) {
            uint2 sample = min(gid + uint2(dx, dy), uint2(rgb.get_width() - 1, rgb.get_height() - 1));
            average += planarYCbCr(rgb.read(sample).rgb, p);
        }
    }
    average *= 0.25f;
    uvPlane.write(float4(planarCode(average.y, true, p), planarCode(average.z, true, p), 0, 1), gid / 2);
}
