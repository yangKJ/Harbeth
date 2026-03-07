//
//  C7ColorBalanceEnhanced.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorBalanceEnhanced(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   constant float *strength [[buffer(0)]],
                                   constant float3 *shadows [[buffer(1)]],
                                   constant float3 *midtones [[buffer(2)]],
                                   constant float3 *highlights [[buffer(3)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const float4 color = float4(inColor);
    
    // Calculate luminance
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    
    // Calculate shadow, midtone, and highlight weights
    float shadowWeight = smoothstep(0.0, 0.3, luminance);
    float highlightWeight = smoothstep(0.7, 1.0, luminance);
    float midtoneWeight = 1.0 - shadowWeight - highlightWeight;
    
    // Apply color balance adjustments
    float3 balanceAdjustment = (*shadows) * shadowWeight + (*midtones) * midtoneWeight + (*highlights) * highlightWeight;
    
    // Apply strength
    float3 finalAdjustment = balanceAdjustment * float(*strength);
    
    // Apply adjustment to color
    float4 outColor = color;
    outColor.rgb += finalAdjustment;
    outColor.rgb = clamp(outColor.rgb, 0.0, 1.0);
    
    outputTexture.write(half4(outColor), grid);
}
