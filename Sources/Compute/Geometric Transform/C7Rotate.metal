//
//  C7Rotate.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

namespace rotate {
    METAL_FUNC float4 sampleColor(texture2d<float, access::sample> inputTexture,
                                 float2 coord,
                                 int samplingMode,
                                 int edgeMode,
                                 bool orthogonalHint) {
        constexpr sampler nearestTransparent(coord::normalized, address::clamp_to_zero, filter::nearest);
        constexpr sampler linearTransparent(coord::normalized, address::clamp_to_zero, filter::linear);
        constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);
        constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
        constexpr sampler nearestRepeat(coord::normalized, address::repeat, filter::nearest);
        constexpr sampler linearRepeat(coord::normalized, address::repeat, filter::linear);
        constexpr sampler nearestMirror(coord::normalized, address::mirrored_repeat, filter::nearest);
        constexpr sampler linearMirror(coord::normalized, address::mirrored_repeat, filter::linear);
        #if defined(__HAVE_BICUBIC_FILTERING__)
        constexpr sampler bicubicTransparent(coord::normalized, address::clamp_to_zero, filter::bicubic);
        constexpr sampler bicubicClamp(coord::normalized, address::clamp_to_edge, filter::bicubic);
        constexpr sampler bicubicRepeat(coord::normalized, address::repeat, filter::bicubic);
        constexpr sampler bicubicMirror(coord::normalized, address::mirrored_repeat, filter::bicubic);
        #endif

        bool useNearest = samplingMode == 0;
        bool useBicubic = false;
        #if defined(__HAVE_BICUBIC_FILTERING__)
        useBicubic = samplingMode == 2 && orthogonalHint;
        #endif

        switch (edgeMode) {
        case 1:
            if (useNearest) { return inputTexture.sample(nearestClamp, coord); }
            #if defined(__HAVE_BICUBIC_FILTERING__)
            if (useBicubic) { return inputTexture.sample(bicubicClamp, coord); }
            #endif
            return inputTexture.sample(linearClamp, coord);
        case 2:
            if (useNearest) { return inputTexture.sample(nearestRepeat, coord); }
            #if defined(__HAVE_BICUBIC_FILTERING__)
            if (useBicubic) { return inputTexture.sample(bicubicRepeat, coord); }
            #endif
            return inputTexture.sample(linearRepeat, coord);
        case 3:
            if (useNearest) { return inputTexture.sample(nearestMirror, coord); }
            #if defined(__HAVE_BICUBIC_FILTERING__)
            if (useBicubic) { return inputTexture.sample(bicubicMirror, coord); }
            #endif
            return inputTexture.sample(linearMirror, coord);
        default:
            if (useNearest) { return inputTexture.sample(nearestTransparent, coord); }
            #if defined(__HAVE_BICUBIC_FILTERING__)
            if (useBicubic) { return inputTexture.sample(bicubicTransparent, coord); }
            #endif
            return inputTexture.sample(linearTransparent, coord);
        }
    }
}

kernel void C7Rotate(texture2d<float, access::write> outputTexture [[texture(0)]],
                     texture2d<float, access::sample> inputTexture [[texture(1)]],
                     constant float *angle [[buffer(0)]],
                     constant float *samplingMode [[buffer(1)]],
                     constant float *edgeMode [[buffer(2)]],
                     constant float &cosAngle [[buffer(3)]],
                     constant float &sinAngle [[buffer(4)]],
                     constant float &halfOutput [[buffer(5)]],
                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    if (*angle == 0.0f && outputTexture.get_width() == inputTexture.get_width() && outputTexture.get_height() == inputTexture.get_height()) {
        const float4 color = inputTexture.read(grid);
        outputTexture.write(halfOutput > 0.5f ? float4(half4(color)) : color, grid);
        return;
    }

    // 像素中心的逆映射避免极坐标奇点；系数在 CPU 每次执行前准备。
    const float2 delta = float2(grid) + 0.5f - float2(outputTexture.get_width(), outputTexture.get_height()) * 0.5f;
    const float w = inputTexture.get_width(), h = inputTexture.get_height();
    const float inX = (delta.x * cosAngle + delta.y * sinAngle + w * 0.5f) / w;
    const float inY = (-delta.x * sinAngle + delta.y * cosAngle + h * 0.5f) / h;

    if (*edgeMode == 0 && (inX < 0 || inX > 1 || inY < 0 || inY > 1)) {
        outputTexture.write(float4(0), grid);
        return;
    }

    float2 sampleCoord = float2(inX, inY);
    const float quarterTurn = float(M_PI_F) * 0.5f;
    const float normalizedTurns = (*angle) / quarterTurn;
    const bool orthogonalHint = abs(normalizedTurns - round(normalizedTurns)) < 0.0001f;
    const float4 outColor = rotate::sampleColor(
        inputTexture,
        sampleCoord,
        int(*samplingMode),
        int(*edgeMode),
        orthogonalHint
    );

    outputTexture.write(halfOutput > 0.5f ? float4(half4(outColor)) : outColor, grid);
}
