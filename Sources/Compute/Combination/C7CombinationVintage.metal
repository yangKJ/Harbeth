#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationVintage(texture2d<half, access::read> inputTexture [[texture(0)]],
                                 texture2d<half, access::read> processedTexture [[texture(1)]],
                                 texture2d<half, access::write> outputTexture [[texture(2)]],
                                 constant float *intensity [[buffer(0)]],
                                 constant float *dustIntensity [[buffer(1)]],
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
    
    // Add subtle dust and scratches effect
    half dust = half(*dustIntensity);
    if (dust > 0.0) {
        // Generate pseudo-random noise for dust effect
        uint2 seed = gid + uint2(1234, 5678);
        float noise = fract(sin(dot(float2(seed), float2(12.9898, 78.233))) * 43758.5453);
        
        // Add dust spots
        if (noise < dust * 0.01) {
            finalColor = finalColor * half(0.3) + half4(0.7, 0.7, 0.7, 1.0) * half(0.7);
        }
        
        // Add scratches
        if (fract(sin(dot(float2(gid), float2(43.34, 76.54))) * 12345.6789) < dust * 0.005) {
            if (gid.y % 2 == 0) {
                finalColor = finalColor * half(0.5) + half4(0.9, 0.9, 0.9, 1.0) * half(0.5);
            }
        }
    }
    
    // Write the result to the output texture
    outputTexture.write(finalColor, gid);
}
