//
//  C7Levels.metal
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

#include <metal_stdlib>
using namespace metal;

#define C7LevelsInputRange(color, minInput, maxInput) \
min(max(color - minInput, half3(0.0)) / (maxInput - minInput), half3(1.0))

#define C7LevelsInput(color, minInput, gamma, maxInput) \
GammaCorrection(C7LevelsInputRange(color, minInput, maxInput), gamma)

#define C7LevelsOutputRange(color, minOutput, maxOutput) mix(minOutput, maxOutput, color)

#define C7LevelsColor(color, minInput, gamma, maxInput, minOutput, maxOutput) \
C7LevelsOutputRange(C7LevelsInput(color, minInput, gamma, maxInput), minOutput, maxOutput)

// Gamma correction
// http://blog.mouaif.org/2009/01/22/photoshop-gamma-correction-shader
#define GammaCorrection(color, gamma) pow(color, 1.0 / gamma)

kernel void  C7LevelsFilter(texture2d<half, access::write> outputTexture [[texture(0)]],
                            texture2d<half, access::read> inputTexture [[texture(1)]],
                            constant float3 *minimum [[buffer(0)]],
                            constant float3 *middle [[buffer(1)]],
                            constant float3 *maximum [[buffer(2)]],
                            constant float3 *minOutput [[buffer(3)]],
                            constant float3 *maxOutput [[buffer(4)]],
                            uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half3 rgb = C7LevelsColor(inColor.rgb, half3(*minimum), half3(*middle), half3(*maximum), half3(*minOutput), half3(*maxOutput));
    const half4 outColor = half4(rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
