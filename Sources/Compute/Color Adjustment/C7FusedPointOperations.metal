// 由 Condy 维护。预乘颜色数学与独立点运算一致，每步保留目标格式舍入。
#include <metal_stdlib>
using namespace metal;

static float4 pointStorage(float4 color, float storage) {
    if (storage == 1.0f) return float4(half4(color));
    if (storage == 2.0f) return rint(clamp(color, 0.0f, 1.0f) * 255.0f) / 255.0f;
    return color;
}
// 白平衡内核由 Condy 创建于 2022/2/15。
// 白平衡的 SDR 限幅和暖色分段都可以在预乘域求值。
static inline float4 mathWhiteBalance(float4 color, float amount, float tint) {
    if (amount == 0.0f && tint == 0.0f) return color;
    if (color.a <= 0.0f) return float4(0);
    const float alpha = color.a;
    float3 rgb = color.rgb;
    if (tint != 0.0f) {
        const float3x3 toYIQ = float3x3(float3(0.299f, 0.587f, 0.114f), float3(0.596f, -0.274f, -0.322f), float3(0.212f, -0.523f, 0.311f));
        const float3x3 toRGB = float3x3(float3(1.0f, 0.956f, 0.621f), float3(1.0f, -0.272f, -0.647f), float3(1.0f, -1.105f, 1.702f));
        float3 yiq = toYIQ * rgb;
        const float shifted = yiq.b + (tint * 0.05226f) * alpha;
        const float limit = 0.5226f * alpha;
        yiq.b = all(rgb >= 0.0f) && all(rgb <= alpha) ? clamp(shifted, -limit, limit) : shifted;
        rgb = toRGB * yiq;
    }
    if (amount != 0.0f) {
        const float3 warm = float3(0.93f, 0.54f, 0.0f);
        const float3 lower = 2.0f * rgb * warm;
        const float3 upper = alpha + 2.0f * (1.0f - warm) * (rgb - alpha);
        const float3 mixed = select(upper, lower, rgb < 0.5f * alpha);
        rgb = rgb + (mixed - rgb) * amount;
    }
    return float4(rgb, alpha);
}

kernel void C7WhiteBalance(texture2d<float, access::write> outputTexture [[texture(0)]],
                           texture2d<float, access::read> inputTexture [[texture(1)]],
                           constant float &temperature [[buffer(0)]],
                           constant float &tint [[buffer(1)]],
                           constant float &halfOutput [[buffer(2)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float amount = (temperature < 5000.0f ? 0.0004f : 0.00006f) * (temperature - 5000.0f);
    outputTexture.write(pointStorage(mathWhiteBalance(inputTexture.read(grid), amount, tint / 100.0f), halfOutput), grid);
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
static inline float4 applyPointOperation(float4 color, int kind, float value, float secondaryValue, float storage) {
    switch (kind) {
        case 0: return pointBrightness(color, value, storage);
        case 1: return pointContrast(color, value, storage);
        case 2: return pointSaturation(color, value, storage);
        case 3: return pointExposure(color, value, storage);
        case 4: return pointGamma(color, value, storage);
        case 5: return pointOpacity(color, value, storage);
        case 6: return pointStorage(mathWhiteBalance(color, value, secondaryValue), storage);
        default: return color;
    }
}

kernel void C7FusedPointOperations(texture2d<float, access::write> outputTexture [[texture(0)]],
                                   texture2d<float, access::read> inputTexture [[texture(1)]],
                                   constant packed_float3 *operations [[buffer(0)]],
                                   constant int &operationCount [[buffer(1)]],
                                   constant float &storage [[buffer(2)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    float4 color = inputTexture.read(grid);
    for (int index = 0; index < operationCount; ++index) color = applyPointOperation(color, int(operations[index].x), operations[index].y, operations[index].z, storage);
    outputTexture.write(color, grid);
}

constant int pointwiseKinds [[function_constant(0)]];
constant int pointwiseCount [[function_constant(1)]];

kernel void C7FusedPointOperationsSpecialized(texture2d<float, access::write> outputTexture [[texture(0)]],
                                             texture2d<float, access::read> inputTexture [[texture(1)]],
                                             constant packed_float3 *operations [[buffer(0)]],
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
            case 6: color = pointStorage(mathWhiteBalance(color, value, operations[index].z), storage); break;
        }
    }
    outputTexture.write(color, grid);
}
