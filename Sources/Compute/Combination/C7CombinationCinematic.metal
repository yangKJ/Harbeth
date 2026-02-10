#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationCinematic(texture2d<half, access::read> inputTexture [[texture(0)]],
                                   texture2d<half, access::read> processedTexture [[texture(1)]],
                                   texture2d<half, access::write> outputTexture [[texture(2)]],
                                   constant float *intensity [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    // Get the dimensions of the input texture
    uint2 dimensions = inputTexture.get_width() * uint2(1, 1);
    if (gid.x >= dimensions.x || gid.y >= dimensions.y) {
        return;
    }
    
    // Read the original and processed pixels
    half4 originalColor = inputTexture.read(gid);
    half4 processedColor = processedTexture.read(gid);
    
    // Blend the original and processed colors based on intensity
    half blendIntensity = half(*intensity);
    half4 finalColor = mix(originalColor, processedColor, blendIntensity);
    
    // Write the result to the output texture
    outputTexture.write(finalColor, gid);
}
