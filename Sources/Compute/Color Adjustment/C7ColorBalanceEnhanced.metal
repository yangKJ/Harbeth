//
//  C7ColorBalanceEnhanced.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorBalanceEnhanced(texture2d<float, access::write> outputTexture [[texture(0)]],
                                   texture2d<float, access::read> inputTexture [[texture(1)]],
                                   constant float *strength [[buffer(0)]],
                                   constant float3 *shadows [[buffer(1)]],
                                   constant float3 *midtones [[buffer(2)]],
                                   constant float3 *highlights [[buffer(3)]],
                                   constant float &halfOutput [[buffer(4)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float4 color = inputTexture.read(grid);
    if (*strength == 0.0f || (all(*shadows == 0.0f) && all(*midtones == 0.0f) && all(*highlights == 0.0f))) {
        outputTexture.write(color, grid); return;
    }
    if (color.a <= 0.0f) { outputTexture.write(float4(0), grid); return; }
    const float luminance = dot(color.rgb / color.a, float3(0.2126f, 0.7152f, 0.0722f));
    const float shadowWeight = 1.0f - smoothstep(0.0f, 0.3f, luminance);
    const float highlightWeight = smoothstep(0.7f, 1.0f, luminance);
    const float midtoneWeight = max(0.0f, 1.0f - shadowWeight - highlightWeight);
    const float3 adjustment = *shadows * shadowWeight + *midtones * midtoneWeight + *highlights * highlightWeight;
    const float4 result = float4(color.rgb + adjustment * (*strength) * color.a, color.a);
    outputTexture.write(halfOutput > 0.5f ? float4(half4(result)) : result, grid);
}
