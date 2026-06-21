//
//  C7Crop.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

#include <metal_stdlib>
using namespace metal;

namespace crop {
    METAL_FUNC half4 sampleColor(texture2d<half, access::sample> inputTexture,
                                 float2 coord,
                                 int samplingMode,
                                 int edgeMode) {
        constexpr sampler nearestTransparent(coord::normalized, address::clamp_to_zero, filter::nearest);
        constexpr sampler linearTransparent(coord::normalized, address::clamp_to_zero, filter::linear);
        constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);
        constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
        constexpr sampler nearestRepeat(coord::normalized, address::repeat, filter::nearest);
        constexpr sampler linearRepeat(coord::normalized, address::repeat, filter::linear);
        constexpr sampler nearestMirror(coord::normalized, address::mirrored_repeat, filter::nearest);
        constexpr sampler linearMirror(coord::normalized, address::mirrored_repeat, filter::linear);

        switch (edgeMode) {
        case 1:
            return samplingMode == 0 ? inputTexture.sample(nearestClamp, coord) : inputTexture.sample(linearClamp, coord);
        case 2:
            return samplingMode == 0 ? inputTexture.sample(nearestRepeat, coord) : inputTexture.sample(linearRepeat, coord);
        case 3:
            return samplingMode == 0 ? inputTexture.sample(nearestMirror, coord) : inputTexture.sample(linearMirror, coord);
        default:
            return samplingMode == 0 ? inputTexture.sample(nearestTransparent, coord) : inputTexture.sample(linearTransparent, coord);
        }
    }
}

kernel void C7Crop(texture2d<half, access::write> outputTexture [[texture(0)]],
                   texture2d<half, access::sample> inputTexture [[texture(1)]],
                   constant float *originX [[buffer(0)]],
                   constant float *originY [[buffer(1)]],
                   constant float *samplingMode [[buffer(2)]],
                   constant float *edgeMode [[buffer(3)]],
                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }

    const float minX = inputTexture.get_width()  * (*originX);
    const float minY = inputTexture.get_height() * (*originY);

    float2 sampleCoord = float2((grid.x + minX) / inputTexture.get_width(), (grid.y + minY) / inputTexture.get_height());
    if (*edgeMode == 0 &&
        (sampleCoord.x < 0.0 || sampleCoord.x > 1.0 || sampleCoord.y < 0.0 || sampleCoord.y > 1.0)) {
        outputTexture.write(half4(0), grid);
        return;
    }
    const half4 outColor = crop::sampleColor(
        inputTexture,
        sampleCoord,
        int(*samplingMode),
        int(*edgeMode)
    );

    outputTexture.write(outColor, grid);
}
