#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationModernHDR(texture2d<half, access::read> inputTexture [[texture(0)]],
                                   texture2d<half, access::read> processedTexture [[texture(1)]],
                                   texture2d<half, access::write> outputTexture [[texture(2)]],
                                   constant float *intensity [[buffer(0)]],
                                   constant float *clarity [[buffer(1)]],
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
    
    // Add clarity effect (local contrast enhancement)
    half clarityValue = half(*clarity);
    if (clarityValue > 0.0) {
        // Simple clarity implementation using local averaging
        half4 localAverage = half4(0.0);
        int sampleCount = 0;
        
        // Sample surrounding pixels
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                uint2 samplePos = gid + uint2(i, j);
                if (samplePos.x < dimensions.x && samplePos.y < dimensions.y) {
                    localAverage += processedTexture.read(samplePos);
                    sampleCount++;
                }
            }
        }
        
        if (sampleCount > 0) {
            localAverage /= half(sampleCount);
            
            // Calculate the difference between the center pixel and the local average
            half4 difference = processedColor - localAverage;
            
            // Enhance the difference based on clarity value
            finalColor = localAverage + difference * (half(1.0) + clarityValue);
            finalColor = clamp(finalColor, half4(0.0), half4(1.0));
        }
    }
    
    // Write the result to the output texture
    outputTexture.write(finalColor, gid);
}
