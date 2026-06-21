//
//  C7ProgrammableBlendCoordinateProbe.metal
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

#include <metal_stdlib>
using namespace metal;

constant bool useRightSample [[function_constant(0)]];

kernel void C7ProgrammableBlendCoordinateProbe(texture2d<half, access::write> outputTexture [[texture(0)]],
                                               texture2d<half, access::read> inputTexture [[texture(1)]],
                                               texture2d<half, access::sample> overlayTexture [[texture(2)]],
                                               constant float *intensity [[buffer(0)]],
                                               uint2 grid [[thread_position_in_grid]]) {
    const half4 background = inputTexture.read(grid);
    constexpr sampler quadSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    const float sampleX = useRightSample ? 0.75 : 0.25;
    const float sampleY = (float(grid.y) + 0.5) / max(float(outputTexture.get_height()), 1.0);
    const half4 overlay = overlayTexture.sample(quadSampler, float2(sampleX, sampleY));
    const half4 output = mix(background, overlay, half(*intensity));
    outputTexture.write(output, grid);
}
