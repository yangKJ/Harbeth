//
//  C7ColorCorrection.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorCorrection(texture2d<half, access::write> outputTexture [[texture(0)]],
                              texture2d<half, access::read> inputTexture [[texture(1)]],
                              constant float *levels [[buffer(0)]],
                              constant float *curves [[buffer(1)]],
                              constant float *colorBalance [[buffer(2)]],
                              uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half levelsAmount = half(*levels);
    const half curvesAmount = half(*curves);
    const half colorBalanceAmount = half(*colorBalance);
    
    half3 color = inColor.rgb;
    
    if (levelsAmount != 0.0h) {
        half minInput = 0.0h + abs(levelsAmount) * 0.1h;
        half maxInput = 1.0h - abs(levelsAmount) * 0.1h;
        half gamma = 1.0h - levelsAmount * 0.3h;
        color = (color - minInput) / (maxInput - minInput);
        color = pow(max(color, 0.0h), gamma);
    }

    if (curvesAmount != 0.0h) {
        half curveStrength = abs(curvesAmount) * 0.5h;
        for (int i = 0; i < 3; i++) {
            half c = color[i];
            if (c < 0.0h) {
                // Pass through negative values (shouldn't occur normally)
            } else if (c < 0.5h) {
                color[i] = pow(c / 0.5h, 1.0h + curveStrength) * 0.5h;
            } else if (c <= 1.0h) {
                color[i] = 1.0h - pow((1.0h - c) / 0.5h, 1.0h + curveStrength) * 0.5h;
            }
            // Values > 1.0 pass through to preserve HDR
        }
    }

    if (colorBalanceAmount != 0.0h) {
        half balanceStrength = abs(colorBalanceAmount) * 0.2h;
        color.r += balanceStrength * 0.5h * sign(colorBalanceAmount);
        color.g += balanceStrength * 0.2h * sign(colorBalanceAmount);
        color.b -= balanceStrength * 0.3h * sign(colorBalanceAmount);
    }
    const half4 outColor = half4(color, inColor.a);
    
    outputTexture.write(outColor, grid);
}
