//
//  C7ColorCube.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

static inline float4 cubeOutputColor(float4 value, float halfOutput) {
    return halfOutput > 0.5f ? float4(half4(value)) : value;
}

static inline float3 cubeRead(texture3d<float, access::read> lutTexture, int3 coordinate, int dimension) {
    return lutTexture.read(uint3(clamp(coordinate, int3(0), int3(dimension - 1)))).rgb;
}

static inline float3 cubeTrilinear(texture3d<float, access::read> lutTexture, int3 base, float3 fraction, int dimension) {
    const float3 c000 = cubeRead(lutTexture, base, dimension);
    const float3 c100 = cubeRead(lutTexture, base + int3(1, 0, 0), dimension);
    const float3 c010 = cubeRead(lutTexture, base + int3(0, 1, 0), dimension);
    const float3 c110 = cubeRead(lutTexture, base + int3(1, 1, 0), dimension);
    const float3 c001 = cubeRead(lutTexture, base + int3(0, 0, 1), dimension);
    const float3 c101 = cubeRead(lutTexture, base + int3(1, 0, 1), dimension);
    const float3 c011 = cubeRead(lutTexture, base + int3(0, 1, 1), dimension);
    const float3 c111 = cubeRead(lutTexture, base + int3(1, 1, 1), dimension);
    const float3 c00 = mix(c000, c100, fraction.x);
    const float3 c10 = mix(c010, c110, fraction.x);
    const float3 c01 = mix(c001, c101, fraction.x);
    const float3 c11 = mix(c011, c111, fraction.x);
    return mix(mix(c00, c10, fraction.y), mix(c01, c11, fraction.y), fraction.z);
}

static inline float3 cubeTetrahedral(texture3d<float, access::read> lutTexture, int3 base, float3 f, int dimension) {
    int3 first, second;
    float3 weights;
    if (f.x >= f.y) {
        if (f.y >= f.z) {
            first = int3(1, 0, 0); second = int3(1, 1, 0); weights = f.xyz;
        } else if (f.x >= f.z) {
            first = int3(1, 0, 0); second = int3(1, 0, 1); weights = f.xzy;
        } else {
            first = int3(0, 0, 1); second = int3(1, 0, 1); weights = f.zxy;
        }
    } else {
        if (f.z >= f.y) {
            first = int3(0, 0, 1); second = int3(0, 1, 1); weights = f.zyx;
        } else if (f.z >= f.x) {
            first = int3(0, 1, 0); second = int3(0, 1, 1); weights = f.yzx;
        } else {
            first = int3(0, 1, 0); second = int3(1, 1, 0); weights = f.yxz;
        }
    }
    const float3 c0 = cubeRead(lutTexture, base, dimension);
    const float3 ca = cubeRead(lutTexture, base + first, dimension);
    const float3 cb = cubeRead(lutTexture, base + second, dimension);
    const float3 c1 = cubeRead(lutTexture, base + int3(1), dimension);
    return c0 + weights.x * (ca - c0) + weights.y * (cb - ca) + weights.z * (c1 - cb);
}

static inline float cubeNormalize(float value, float minimum, float maximum) {
    if (value <= minimum) return 0.0f;
    if (value >= maximum) return 1.0f;
    const float span = maximum - minimum;
    const float normalized = isfinite(span) ? precise::divide(value - minimum, span)
        : precise::divide(value * 0.5f - minimum * 0.5f, maximum * 0.5f - minimum * 0.5f);
    return clamp(normalized, 0.0f, 1.0f);
}

kernel void C7ColorCube(texture2d<float, access::write> outputTexture [[texture(0)]],
                        texture2d<float, access::read> inputTexture [[texture(1)]],
                        texture3d<float, access::read> lutTexture [[texture(2)]],
                        constant float &intensity [[buffer(0)]],
                        constant float &interpolation [[buffer(1)]],
                        constant float3 &domainMinimum [[buffer(2)]],
                         constant float3 &domainMaximum [[buffer(3)]],
                         constant float &domainPolicy [[buffer(4)]],
                        constant float &halfOutput [[buffer(5)]],
                        uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float4 input = inputTexture.read(grid);
    if (intensity <= 0.0f) {
        outputTexture.write(cubeOutputColor(input, halfOutput), grid);
        return;
    }
    const float3 inputRGB = input.rgb;
    if (domainPolicy >= 0.5f && (any(inputRGB < domainMinimum) || any(inputRGB > domainMaximum))) {
        outputTexture.write(cubeOutputColor(input, halfOutput), grid);
        return;
    }
    const bool unitDomain = all(domainMinimum == float3(0.0f)) && all(domainMaximum == float3(1.0f));
    // 单位输入域只需钳制，同时保留通用归一化对负零的处理。
    const float3 normalized = unitDomain
        ? select(clamp(inputRGB, 0.0f, 1.0f), float3(0.0f), inputRGB <= 0.0f)
        : float3(cubeNormalize(inputRGB.r, domainMinimum.r, domainMaximum.r),
                 cubeNormalize(inputRGB.g, domainMinimum.g, domainMaximum.g),
                 cubeNormalize(inputRGB.b, domainMinimum.b, domainMaximum.b));
    const int dimension = int(lutTexture.get_width());
    const float3 scaled = normalized * float(dimension - 1);
    const int3 base = int3(floor(scaled));
    const float3 fraction = scaled - float3(base);
    const bool useTetrahedral = interpolation >= 0.5f;
    const float3 mapped = useTetrahedral
        ? cubeTetrahedral(lutTexture, base, fraction, dimension)
        : cubeTrilinear(lutTexture, base, fraction, dimension);
    const float mixFactor = clamp(intensity, 0.0f, 1.0f);
    outputTexture.write(cubeOutputColor(float4(mix(input.rgb, mapped, mixFactor), input.a), halfOutput), grid);
}
