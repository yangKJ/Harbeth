//
//  C7ColorCube.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

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
    const float3 c000 = cubeRead(lutTexture, base, dimension);
    const float3 c100 = cubeRead(lutTexture, base + int3(1, 0, 0), dimension);
    const float3 c010 = cubeRead(lutTexture, base + int3(0, 1, 0), dimension);
    const float3 c001 = cubeRead(lutTexture, base + int3(0, 0, 1), dimension);
    const float3 c110 = cubeRead(lutTexture, base + int3(1, 1, 0), dimension);
    const float3 c101 = cubeRead(lutTexture, base + int3(1, 0, 1), dimension);
    const float3 c011 = cubeRead(lutTexture, base + int3(0, 1, 1), dimension);
    const float3 c111 = cubeRead(lutTexture, base + int3(1, 1, 1), dimension);

    if (f.x >= f.y) {
        if (f.y >= f.z) {
            return c000 + f.x * (c100 - c000) + f.y * (c110 - c100) + f.z * (c111 - c110);
        }
        if (f.x >= f.z) {
            return c000 + f.x * (c100 - c000) + f.z * (c101 - c100) + f.y * (c111 - c101);
        }
        return c000 + f.z * (c001 - c000) + f.x * (c101 - c001) + f.y * (c111 - c101);
    }
    if (f.z >= f.y) {
        return c000 + f.z * (c001 - c000) + f.y * (c011 - c001) + f.x * (c111 - c011);
    }
    if (f.z >= f.x) {
        return c000 + f.y * (c010 - c000) + f.z * (c011 - c010) + f.x * (c111 - c011);
    }
    return c000 + f.y * (c010 - c000) + f.x * (c110 - c010) + f.z * (c111 - c110);
}

kernel void C7ColorCube(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        texture3d<float, access::read> lutTexture [[texture(2)]],
                        constant float *intensityPointer [[buffer(0)]],
                        constant float *interpolationPointer [[buffer(1)]],
                        constant float *domainMinimumX [[buffer(2)]],
                        constant float *domainMinimumY [[buffer(3)]],
                        constant float *domainMinimumZ [[buffer(4)]],
                        constant float *domainMaximumX [[buffer(5)]],
                        constant float *domainMaximumY [[buffer(6)]],
                        constant float *domainMaximumZ [[buffer(7)]],
                        uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 input = inputTexture.read(grid);
    const float3 domainMinimum = float3(*domainMinimumX, *domainMinimumY, *domainMinimumZ);
    const float3 domainMaximum = float3(*domainMaximumX, *domainMaximumY, *domainMaximumZ);
    const float3 domainSize = max(domainMaximum - domainMinimum, float3(1e-6f));
    const float3 normalized = clamp((float3(input.rgb) - domainMinimum) / domainSize, 0.0f, 1.0f);
    const int dimension = int(lutTexture.get_width());
    const float3 scaled = normalized * float(dimension - 1);
    const int3 base = int3(floor(scaled));
    const float3 fraction = scaled - float3(base);
    const bool useTetrahedral = *interpolationPointer >= 0.5f;
    const float3 mapped = useTetrahedral
        ? cubeTetrahedral(lutTexture, base, fraction, dimension)
        : cubeTrilinear(lutTexture, base, fraction, dimension);
    const half mixFactor = half(clamp(*intensityPointer, 0.0f, 1.0f));
    outputTexture.write(half4(mix(input.rgb, half3(mapped), mixFactor), input.a), grid);
}
