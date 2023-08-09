//
//  C7CombinationBeautiful.metal
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationBeautiful(texture2d<half, access::write> outputTexture [[texture(0)]],
                                   texture2d<half, access::read> inputTexture [[texture(1)]],
                                   texture2d<half, access::read> blurTexture [[texture(2)]],
                                   texture2d<half, access::read> edgeTexture [[texture(3)]],
                                   constant float *intensity [[buffer(0)]],
                                   constant float *smoothDegree [[buffer(1)]],
                                   uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    const half4 blur = blurTexture.read(grid);
    const half4 edge = edgeTexture.read(grid);
    
    const half r = inColor.r;
    const half g = inColor.g;
    const half b = inColor.b;
    
    half4 outColor;
    if (edge.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > g && r > b && r - min(g, b) > 0.0588 && r - g > 0.0588) {
        // Skin detection method
        // https://blog.csdn.net/Trent1985/article/details/50496969
        outColor = (1.0 - half(*smoothDegree)) * inColor + half(*smoothDegree) * blur;
    } else {
        outColor = inColor;
    }
    outColor.r = log(1.0 + 0.2 * outColor.r) / log(1.2);
    outColor.g = log(1.0 + 0.2 * outColor.g) / log(1.2);
    outColor.b = log(1.0 + 0.2 * outColor.b) / log(1.2);
    
    const half4 output = mix(inColor, outColor, half(*intensity));
    
    outputTexture.write(output, grid);
}
