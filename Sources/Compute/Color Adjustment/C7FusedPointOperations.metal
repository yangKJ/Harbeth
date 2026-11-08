//
//  C7FusedPointOperations.metal
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

#include <metal_stdlib>
using namespace metal;

static inline half4 applyPointOperation(half4 color, int kind, float value) {
    switch (kind) {
        case 0:
            color = half4(color.rgb + half3(half(value)), color.a);
            break;
        case 1:
            color = half4(half3(0.5h) + (color.rgb - half3(0.5h)) * value, color.a);
            break;
        case 2: {
            const half luminance = dot(color.rgb, half3(0.2125h, 0.7154h, 0.0721h));
            color = half4(mix(half3(luminance), color.rgb, half(value)), color.a);
            break;
        }
        case 3:
            color = half4(color.rgb * half(pow(2.0f, value)), color.a);
            break;
        case 4:
            color = half4(pow(color.rgb, half3(half(value))), color.a);
            break;
        case 5:
            color = half4(color.rgb, half(value) * color.a);
            break;
        default:
            break;
    }
    return color;
}

kernel void C7FusedPointOperations(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   constant float2 *operations [[buffer(0)]],
                                   constant int &operationCount [[buffer(1)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    half4 color = inputTexture.read(grid);
    for (int index = 0; index < operationCount; ++index) {
        const int kind = int(operations[index].x);
        const float value = operations[index].y;
        color = applyPointOperation(color, kind, value);
    }
    outputTexture.write(color, grid);
}

// 独立调用边界保留每步 half 量化，避免展开后跨操作合并浮点表达式。
static __attribute__((noinline)) half4 pointBrightness(half4 color, float value) {
    return half4(color.rgb + half3(half(value)), color.a);
}
static __attribute__((noinline)) half4 pointContrast(half4 color, float value) {
    return half4(half3(0.5h) + (color.rgb - half3(0.5h)) * value, color.a);
}
static __attribute__((noinline)) half4 pointSaturation(half4 color, float value) {
    const half luminance = dot(color.rgb, half3(0.2125h, 0.7154h, 0.0721h));
    return half4(mix(half3(luminance), color.rgb, half(value)), color.a);
}
static __attribute__((noinline)) half4 pointExposure(half4 color, float value) {
    return half4(color.rgb * half(pow(2.0f, value)), color.a);
}
static __attribute__((noinline)) half4 pointGamma(half4 color, float value) {
    return half4(pow(color.rgb, half3(half(value))), color.a);
}
static __attribute__((noinline)) half4 pointOpacity(half4 color, float value) {
    return half4(color.rgb, half(value) * color.a);
}

constant int pointwiseKinds [[function_constant(0)]];
constant int pointwiseCount [[function_constant(1)]];

kernel void C7FusedPointOperationsSpecialized(texture2d<half, access::write> outputTexture [[texture(0)]],
                                             texture2d<half, access::read> inputTexture [[texture(1)]],
                                             constant float2 *operations [[buffer(0)]],
                                             uint2 grid [[thread_position_in_grid]]) {
    #pragma clang fp reassociate(off) contract(off)
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    half4 color = inputTexture.read(grid);
    // 只展开控制流；禁止跨步重结合，保留 half 舍入及操作顺序。
    #pragma unroll
    for (int index = 0; index < pointwiseCount; ++index) {
        const float value = operations[index].y;
        switch ((pointwiseKinds >> (index * 3)) & 7) {
            case 0: color = pointBrightness(color, value); break;
            case 1: color = pointContrast(color, value); break;
            case 2: color = pointSaturation(color, value); break;
            case 3: color = pointExposure(color, value); break;
            case 4: color = pointGamma(color, value); break;
            case 5: color = pointOpacity(color, value); break;
        }
    }
    outputTexture.write(color, grid);
}
