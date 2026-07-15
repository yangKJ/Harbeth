//
//  C7AffineTransform.metal
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

#include <metal_stdlib>
using namespace metal;

namespace transform {
    METAL_FUNC bool zeroOrOne(float x) {
        if (abs(x - round(x)) >= 1e-10) { return false; }
        float a = abs(round(x));
        return a == 0 || a == 1;
    }

    METAL_FUNC half4 sampleColor(texture2d<half, access::sample> inputTexture,
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

kernel void C7AffineTransform(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::sample> inputTexture [[texture(1)]],
                              constant float *anchorPointX [[buffer(0)]],
                              constant float *anchorPointY [[buffer(1)]],
                              constant float *samplingMode [[buffer(2)]],
                              constant float *edgeMode [[buffer(3)]],
                              constant float3x2 *transformMatrix [[buffer(4)]],
                              constant float4 *regionContext [[buffer(30)]],
                              uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float3x2 matrix = *transformMatrix;
    const float a = matrix[0][0], b = matrix[0][1];
    const float c = matrix[1][0], d = matrix[1][1];
    const float4 inputRegion = regionContext[0];
    const float4 outputRegion = regionContext[1];
    const float w = inputRegion.z;
    const float h = inputRegion.w;
    const float anchorX = (*anchorPointX);
    const float anchorY = (*anchorPointY);

    if (a * d - b * c == 0) {
        outputTexture.write(half4(0), grid);
        return;
    }

    const float2 globalOutput = float2(grid) + outputRegion.xy;
    const float outX = globalOutput.x - outputRegion.z * anchorX;
    const float outY = globalOutput.y - outputRegion.w * anchorY;

    const float tx = matrix[2][0], ty = matrix[2][1];

    const float inX = (d * outX - c * outY - d * tx + c * ty) / (a * d - b * c) / w + anchorX;
    const float inY = (b * outX - a * outY - b * tx + a * ty) / (b * c - a * d) / h + anchorY;

    // Set empty pixel when out of range
    if (*edgeMode == 0 && (inX < 0 || inX > 1 || inY < 0 || inY > 1)) {
        outputTexture.write(half4(0), grid);
        return;
    }

    const float2 globalInput = float2(inX * w, inY * h);
    float2 sampleCoord = (globalInput - inputRegion.xy) /
        float2(inputTexture.get_width(), inputTexture.get_height());
    const bool orthogonalHint =
        transform::zeroOrOne(a) &&
        transform::zeroOrOne(b) &&
        transform::zeroOrOne(c) &&
        transform::zeroOrOne(d);
    const half4 outColor = transform::sampleColor(
        inputTexture,
        sampleCoord,
        int(*samplingMode),
        int(*edgeMode),
        orthogonalHint
    );

    outputTexture.write(outColor, grid);
}
