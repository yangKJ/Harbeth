//
//  C7ColorCube.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

// Helper function to calculate 2D texture coordinates from 3D LUT coordinates
uint2 calculateTextureCoord(int3 coord, int dimension, int textureWidth) {
    // Ensure coordinates are within bounds
    coord = clamp(coord, int3(0), int3(dimension - 1));
    
    // Layout: each row is a G slice, each column is R + B * dimension
    int x = coord.x + coord.z * dimension;
    int y = coord.y;
    
    // Ensure coordinates are within texture bounds
    x = min(x, textureWidth - 1);
    y = min(y, dimension - 1);
    
    return uint2(x, y);
}

kernel void C7ColorCube(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        texture2d<float, access::read> lutTexture [[texture(2)]],
                        constant float *intensity [[buffer(0)]],
                        uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    
    const half4 inColor = inputTexture.read(grid);
    
    // Clamp input color to [0,1] range
    const float r = clamp(float(inColor.r), 0.0, 1.0);
    const float g = clamp(float(inColor.g), 0.0, 1.0);
    const float b = clamp(float(inColor.b), 0.0, 1.0);
    
    const int lutDimension = int(lutTexture.get_height());
    const int textureWidth = int(lutTexture.get_width());
    
    // Calculate 3D LUT coordinates
    // Map [0,1] to [0, dimension-1]
    const float3 scaledCoord = float3(r, g, b) * float(lutDimension - 1);
    
    // Get integer and fractional parts
    const int3 intCoord = int3(floor(scaledCoord));
    const float3 fracCoord = scaledCoord - float3(intCoord);
    
    // Calculate 2D texture coordinates for all eight corners of the cube
    const int3 coord000 = intCoord;
    const int3 coord100 = intCoord + int3(1, 0, 0);
    const int3 coord010 = intCoord + int3(0, 1, 0);
    const int3 coord110 = intCoord + int3(1, 1, 0);
    const int3 coord001 = intCoord + int3(0, 0, 1);
    const int3 coord101 = intCoord + int3(1, 0, 1);
    const int3 coord011 = intCoord + int3(0, 1, 1);
    const int3 coord111 = intCoord + int3(1, 1, 1);
    
    // Read all eight corner colors
    const float4 c000 = lutTexture.read(calculateTextureCoord(coord000, lutDimension, textureWidth));
    const float4 c100 = lutTexture.read(calculateTextureCoord(coord100, lutDimension, textureWidth));
    const float4 c010 = lutTexture.read(calculateTextureCoord(coord010, lutDimension, textureWidth));
    const float4 c110 = lutTexture.read(calculateTextureCoord(coord110, lutDimension, textureWidth));
    const float4 c001 = lutTexture.read(calculateTextureCoord(coord001, lutDimension, textureWidth));
    const float4 c101 = lutTexture.read(calculateTextureCoord(coord101, lutDimension, textureWidth));
    const float4 c011 = lutTexture.read(calculateTextureCoord(coord011, lutDimension, textureWidth));
    const float4 c111 = lutTexture.read(calculateTextureCoord(coord111, lutDimension, textureWidth));
    
    // Trilinear interpolation
    // Interpolate along R axis
    const float4 c00 = mix(c000, c100, fracCoord.x);
    const float4 c01 = mix(c010, c110, fracCoord.x);
    const float4 c10 = mix(c001, c101, fracCoord.x);
    const float4 c11 = mix(c011, c111, fracCoord.x);
    
    // Interpolate along G axis
    const float4 c0 = mix(c00, c01, fracCoord.y);
    const float4 c1 = mix(c10, c11, fracCoord.y);
    
    // Interpolate along B axis
    const float4 lutColor = mix(c0, c1, fracCoord.z);
    
    // Clamp LUT color to [0,1] range
    const float4 clampedLutColor = clamp(lutColor, 0.0, 1.0);
    
    // Mix with original color based on intensity
    const float mixFactor = clamp(*intensity, 0.0, 1.0);
    const half3 rgb = mix(inColor.rgb, half3(clampedLutColor.rgb), half(mixFactor));
    const half4 outColor = half4(rgb, inColor.a);
    
    outputTexture.write(outColor, grid);
}
