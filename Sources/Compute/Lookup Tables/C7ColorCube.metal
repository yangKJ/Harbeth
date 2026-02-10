//
//  C7ColorCube.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7ColorCube(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        texture2d<float, access::read> lutTexture [[texture(2)]],
                        constant float *intensity [[buffer(0)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);
    
    const float r = float(inColor.r);
    const float g = float(inColor.g);
    const float b = float(inColor.b);
    
    const int lutDimension = int(lutTexture.get_height());
    const int textureWidth = int(lutTexture.get_width());
    
    // Calculate 3D LUT coordinates
    // Map [0,1] to [0, dimension-1]
    const float3 scaledCoord = float3(r, g, b) * float(lutDimension - 1);
    
    // Get integer and fractional parts
    const int3 intCoord = int3(floor(scaledCoord));
    const float3 fracCoord = scaledCoord - float3(intCoord);
    
    // Calculate 2D texture coordinates for four corners
    // Layout: each row is a G slice, each column is R + B * dimension
    const int x0 = intCoord.x + intCoord.z * lutDimension;
    const int y0 = intCoord.y;
    const int x1 = min(x0 + 1, textureWidth - 1);
    const int y1 = min(y0 + 1, lutDimension - 1);
    
    // Read four corner colors
    const float4 c00 = lutTexture.read(uint2(x0, y0));
    const float4 c10 = lutTexture.read(uint2(x1, y0));
    const float4 c01 = lutTexture.read(uint2(x0, y1));
    const float4 c11 = lutTexture.read(uint2(x1, y1));
    
    // Bilinear interpolation in R-B plane
    const float4 c0 = mix(c00, c10, fracCoord.x);
    const float4 c1 = mix(c01, c11, fracCoord.x);
    
    // Bilinear interpolation in G direction
    const float4 lutColor = mix(c0, c1, fracCoord.y);
    
    // Mix with original color based on intensity
    const half4 outColor = half4(mix(inColor.rgb, half3(lutColor.rgb), half(*intensity)), inColor.a);
    
    outputTexture.write(outColor, grid);
}
