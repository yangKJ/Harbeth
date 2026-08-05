//
//  C7HexagonalBokehBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

#define HEXAGONAL_BOKEH_SAMPLE_PAIRS 6

static inline half3 hexagonalBokehStraightColor(half4 color) {
    return color.a > half(0.0) ? color.rgb / color.a : half3(0.0);
}

static inline half4 hexagonalBokehReadClamped(texture2d<half, access::read> texture, int2 coordinate) {
    const int2 maximum = int2(texture.get_width() - 1, texture.get_height() - 1);
    return texture.read(uint2(clamp(coordinate, int2(0), maximum)));
}

static inline float hexagonalBokehCoC(texture2d<half, access::read> cocTexture,
                                      uint2 gid,
                                      uint2 inputSize) {
    const uint2 cocSize = uint2(cocTexture.get_width(), cocTexture.get_height());
    const float2 normalizedCoordinate = (float2(gid) + 0.5f) / max(float2(inputSize), float2(1.0f));
    const uint2 cocCoordinate = min(
        uint2(normalizedCoordinate * float2(cocSize)),
        cocSize - uint2(1)
    );
    return clamp(fabs(float(cocTexture.read(cocCoordinate).r)), 0.0f, 1.0f);
}

static inline half4 hexagonalBokehBlurAlongAxes(
    texture2d<half, access::read> inputTexture,
    uint2 gid,
    float radius,
    float angleDegrees,
    bool usesFirstTwoAxes
) {
    const half4 center = inputTexture.read(gid);
    if (radius <= 0.0f || center.a <= half(0.0)) {
        return center;
    }

    const float angle = angleDegrees * M_PI_F / 180.0f;
    half3 colorSum = hexagonalBokehStraightColor(center);
    float weightSum = 1.0f;
    const int axisCount = usesFirstTwoAxes ? 2 : 1;
    const int axisStart = usesFirstTwoAxes ? 0 : 2;

    for (int axisIndex = 0; axisIndex < axisCount; axisIndex++) {
        const float axisAngle = angle + float(axisStart + axisIndex) * M_PI_F / 3.0f;
        const float2 direction = float2(cos(axisAngle), sin(axisAngle));
        for (int sampleIndex = 1; sampleIndex <= HEXAGONAL_BOKEH_SAMPLE_PAIRS; sampleIndex++) {
            const float distance = radius * float(sampleIndex) / float(HEXAGONAL_BOKEH_SAMPLE_PAIRS);
            const int2 offset = int2(round(direction * distance));
            if (all(offset == int2(0))) {
                continue;
            }
            colorSum += hexagonalBokehStraightColor(hexagonalBokehReadClamped(inputTexture, int2(gid) + offset));
            colorSum += hexagonalBokehStraightColor(hexagonalBokehReadClamped(inputTexture, int2(gid) - offset));
            weightSum += 2.0f;
        }
    }
    return half4(colorSum / half(weightSum) * center.a, center.a);
}

kernel void C7HexagonalBokehFirstPass(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    constant float *radius [[buffer(0)]],
    constant float *angle [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    outputTexture.write(hexagonalBokehBlurAlongAxes(inputTexture, gid, max(*radius, 0.0f), *angle, true), gid);
}

kernel void C7HexagonalBokehFirstPassWithCoC(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<half, access::read> cocTexture [[texture(2)]],
    constant float *radius [[buffer(0)]],
    constant float *angle [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    const uint2 inputSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    outputTexture.write(hexagonalBokehBlurAlongAxes(inputTexture, gid, max(*radius, 0.0f) * hexagonalBokehCoC(cocTexture, gid, inputSize), *angle, true), gid);
}

kernel void C7HexagonalBokehSecondPass(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    constant float *radius [[buffer(0)]],
    constant float *angle [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    outputTexture.write(hexagonalBokehBlurAlongAxes(inputTexture, gid, max(*radius, 0.0f), *angle, false), gid);
}

kernel void C7HexagonalBokehSecondPassWithCoC(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<half, access::read> cocTexture [[texture(2)]],
    constant float *radius [[buffer(0)]],
    constant float *angle [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    const uint2 inputSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    outputTexture.write(hexagonalBokehBlurAlongAxes(inputTexture, gid, max(*radius, 0.0f) * hexagonalBokehCoC(cocTexture, gid, inputSize), *angle, false), gid);
}

static inline half4 hexagonalBokehComposite(
    half4 source,
    half4 blurred,
    float amount,
    float brightness
) {
    if (amount <= 0.0f || source.a <= half(0.0)) {
        return source;
    }
    const half3 sourceColor = hexagonalBokehStraightColor(source);
    half3 blurredColor = hexagonalBokehStraightColor(blurred);
    const half luminance = dot(max(blurredColor, half3(0.0)), half3(0.2126, 0.7152, 0.0722));
    const half highlightWeight = smoothstep(half(0.5), half(1.0), luminance);
    blurredColor *= half(1.0f + max(brightness, 0.0f)) * highlightWeight + half(1.0) - highlightWeight;
    const half3 result = mix(sourceColor, blurredColor, half(amount));
    return half4(result * source.a, source.a);
}

kernel void C7HexagonalBokehComposite(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<half, access::read> blurredTexture [[texture(2)]],
    constant float *radius [[buffer(0)]],
    constant float *brightness [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    const half4 source = inputTexture.read(gid);
    if (*radius <= 0.0f) {
        outputTexture.write(source, gid);
        return;
    }
    outputTexture.write(hexagonalBokehComposite(source, blurredTexture.read(gid), 1.0f, *brightness), gid);
}

kernel void C7HexagonalBokehCompositeWithCoC(
    texture2d<half, access::write> outputTexture [[texture(0)]],
    texture2d<half, access::read> inputTexture [[texture(1)]],
    texture2d<half, access::read> blurredTexture [[texture(2)]],
    texture2d<half, access::read> cocTexture [[texture(3)]],
    constant float *radius [[buffer(0)]],
    constant float *brightness [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    const half4 source = inputTexture.read(gid);
    if (*radius <= 0.0f) {
        outputTexture.write(source, gid);
        return;
    }
    const uint2 inputSize = uint2(inputTexture.get_width(), inputTexture.get_height());
    outputTexture.write(hexagonalBokehComposite(source, blurredTexture.read(gid), hexagonalBokehCoC(cocTexture, gid, inputSize), *brightness), gid);
}
