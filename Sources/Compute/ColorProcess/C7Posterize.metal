//
//  C7Posterize.metal
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Posterize(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *colorLevelsPointer [[buffer(0)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const half colorLevels = half(*colorLevelsPointer);
    const half4 outColor = floor((inColor * colorLevels) + half4(0.5h)) / colorLevels;
    
    outputTexture.write(outColor, grid);
}
