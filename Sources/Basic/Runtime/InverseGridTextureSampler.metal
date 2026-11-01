//
//  InverseGridTextureSampler.metal
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//
#include <metal_stdlib>
using namespace metal;

struct InverseGridTextureSamplerUniforms {
    float4 sourceRegion;
    float4 sourceExtent;
    float4 outputRegion;
    float2 outputSize;
    float4 outputExtent;
    float4 row0;
    float4 row1;
    float4 row2;
    uint clipsGridBounds;
};

// Float32 texture filtering is optional on supported GPU families; interpolate explicitly.
static float4 inverseGridBilinear(texture2d<float, access::read> image, float2 pixel) {
    int2 lower = int2(floor(pixel));
    float2 weight = fract(pixel);
    int2 limit = int2(image.get_width(), image.get_height()) - 1;
    float4 a = image.read(uint2(clamp(lower, int2(0), limit)));
    float4 b = image.read(uint2(clamp(lower + int2(1, 0), int2(0), limit)));
    float4 c = image.read(uint2(clamp(lower + int2(0, 1), int2(0), limit)));
    float4 d = image.read(uint2(clamp(lower + int2(1, 1), int2(0), limit)));
    return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
}

kernel void InverseGridTextureSampler(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> field [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant InverseGridTextureSamplerUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uint(uniforms.outputSize.x) || gid.y >= uint(uniforms.outputSize.y)) return;
    float2 documentPoint = uniforms.outputRegion.xy + (float2(gid) + 0.5) * uniforms.outputRegion.zw / uniforms.outputSize;
    float2 normalized = (documentPoint - uniforms.outputExtent.xy) / uniforms.outputExtent.zw;
    float3 point = float3(normalized, 1);
    float denominator = dot(uniforms.row2.xyz, point);
    float2 uv = float2(dot(uniforms.row0.xyz, point), dot(uniforms.row1.xyz, point)) / denominator;
    if (abs(denominator) < 1e-8 || (uniforms.clipsGridBounds && (any(uv < 0.0f) || any(uv > 1.0f)))) {
        output.write(float4(0), gid);
        return;
    }
    float2 dimensions = float2(field.get_width(), field.get_height());
    float2 fieldPoint = inverseGridBilinear(field, clamp(uv, 0.0f, 1.0f) * (dimensions - 1)).rg;
    // The grid is expressed in full-document normalized coordinates; sourceRegion
    // only describes the portion that the caller guarantees is resident/readable.
    float2 sourcePoint = uniforms.sourceExtent.xy + fieldPoint * uniforms.sourceExtent.zw;
    float2 sourceUV = (sourcePoint - uniforms.sourceRegion.xy) / uniforms.sourceRegion.zw;
    float2 pixel = sourceUV * float2(source.get_width(), source.get_height()) - .5;
    float4 value = inverseGridBilinear(source, pixel);
    output.write(value, gid);
}
