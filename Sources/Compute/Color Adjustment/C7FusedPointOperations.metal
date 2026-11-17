// 由 Condy 维护。预乘颜色数学与独立点运算一致，每步保留目标格式舍入。
#include <metal_stdlib>
using namespace metal;

static float4 pointStorage(float4 color, float storage) {
    if (storage == 1.0f) return float4(half4(color));
    if (storage == 2.0f) return rint(clamp(color, 0.0f, 1.0f) * 255.0f) / 255.0f;
    return color;
}
static inline float4 mathBrightness(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 0.0f;
    if (value == 0.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    return float4(color.rgb + value * color.a, color.a);
}
static __attribute__((noinline)) float4 pointBrightness(float4 color, float value, float storage) {
    return pointStorage(mathBrightness(color, value), storage);
}
static inline float4 mathContrast(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 1.0f;
    if (value == 1.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    const float3 middle = float3(0.5f * color.a);
    return float4(middle + (color.rgb - middle) * value, color.a);
}
static __attribute__((noinline)) float4 pointContrast(float4 color, float value, float storage) {
    return pointStorage(mathContrast(color, value), storage);
}
static inline float4 mathSaturation(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 1.0f;
    if (value == 1.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    const float gray = dot(color.rgb, float3(0.2125f, 0.7154f, 0.0721f));
    return float4(color.rgb + (float3(gray) - color.rgb) * (1.0f - value), color.a);
}
static __attribute__((noinline)) float4 pointSaturation(float4 color, float value, float storage) {
    return pointStorage(mathSaturation(color, value), storage);
}
static inline float4 mathExposure(float4 color, float parameter) {
    const float value = isfinite(parameter) ? parameter : 0.0f;
    if (value == 0.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    return float4(color.rgb * exp2(value), color.a);
}
static __attribute__((noinline)) float4 pointExposure(float4 color, float value, float storage) {
    return pointStorage(mathExposure(color, value), storage);
}
static inline float4 mathGamma(float4 color, float parameter) {
    const float value = isfinite(parameter) && parameter >= 0.0f ? parameter : 1.0f;
    if (value == 1.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    const float3 signs = select(float3(1), float3(-1), color.rgb < 0.0f);
    if (value == 0.0f) return float4(signs * color.a, color.a);
    const float3 straight = color.rgb / color.a;
    return float4(signs * pow(abs(straight), float3(value)) * color.a, color.a);
}
static __attribute__((noinline)) float4 pointGamma(float4 color, float value, float storage) {
    return pointStorage(mathGamma(color, value), storage);
}
static inline float4 mathOpacity(float4 color, float parameter) {
    const float value = isfinite(parameter) ? clamp(parameter, 0.0f, 1.0f) : 1.0f;
    if (value == 1.0f) return color;
    if (value == 0.0f || color.a <= 0.0f) return float4(0);
    return color * value;
}
static __attribute__((noinline)) float4 pointOpacity(float4 color, float value, float storage) {
    return pointStorage(mathOpacity(color, value), storage);
}
static inline float4 applyPointOperation(float4 color, int kind, float value, float storage) {
    switch (kind) {
        case 0: return pointBrightness(color, value, storage);
        case 1: return pointContrast(color, value, storage);
        case 2: return pointSaturation(color, value, storage);
        case 3: return pointExposure(color, value, storage);
        case 4: return pointGamma(color, value, storage);
        case 5: return pointOpacity(color, value, storage);
        default: return color;
    }
}

kernel void C7FusedPointOperations(texture2d<float, access::write> outputTexture [[texture(0)]],
                                   texture2d<float, access::read> inputTexture [[texture(1)]],
                                   constant float2 *operations [[buffer(0)]],
                                   constant int &operationCount [[buffer(1)]],
                                   constant float &storage [[buffer(2)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    float4 color = inputTexture.read(grid);
    for (int index = 0; index < operationCount; ++index) color = applyPointOperation(color, int(operations[index].x), operations[index].y, storage);
    outputTexture.write(color, grid);
}

constant int pointwiseKinds [[function_constant(0)]];
constant int pointwiseCount [[function_constant(1)]];

kernel void C7FusedPointOperationsSpecialized(texture2d<float, access::write> outputTexture [[texture(0)]],
                                             texture2d<float, access::read> inputTexture [[texture(1)]],
                                             constant float2 *operations [[buffer(0)]],
                                             constant float &storage [[buffer(2)]],
                                             uint2 grid [[thread_position_in_grid]]) {
    #pragma clang fp reassociate(off) contract(off)
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    float4 color = inputTexture.read(grid);
    #pragma unroll
    for (int index = 0; index < pointwiseCount; ++index) {
        const float value = operations[index].y;
        switch ((pointwiseKinds >> (index * 3)) & 7) {
            case 0: color = pointBrightness(color, value, storage); break;
            case 1: color = pointContrast(color, value, storage); break;
            case 2: color = pointSaturation(color, value, storage); break;
            case 3: color = pointExposure(color, value, storage); break;
            case 4: color = pointGamma(color, value, storage); break;
            case 5: color = pointOpacity(color, value, storage); break;
        }
    }
    outputTexture.write(color, grid);
}
