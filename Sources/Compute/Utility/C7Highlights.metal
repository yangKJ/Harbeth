#include <metal_stdlib>
using namespace metal;

kernel void C7Highlights(texture2d<half, access::read> inputTexture [[texture(0)]],
                         texture2d<half, access::write> outputTexture [[texture(1)]],
                         constant float *highlightAmount [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    // Get the dimensions of the input texture
    uint2 dimensions = inputTexture.get_width() * uint2(1, 1);
    if (gid.x >= dimensions.x || gid.y >= dimensions.y) {
        return;
    }
    
    // Read the input pixel
    half4 color = inputTexture.read(gid);
    
    // Calculate luminance to determine highlight areas
    half luminance = dot(color.rgb, half3(0.2126, 0.7152, 0.0722));
    
    // Get the highlight adjustment amount
    half highlight = half(*highlightAmount);
    
    if (highlight > 0.0) {
        // Increase highlight areas (bright pixels)
        half highlightFactor = smoothstep(half(0.5), half(1.0), luminance);
        half adjustment = highlight * highlightFactor;
        color.rgb += adjustment;
    } else if (highlight < 0.0) {
        // Decrease highlight areas (bright pixels)
        half highlightFactor = smoothstep(half(0.5), half(1.0), luminance);
        half adjustment = highlight * (half(1.0) - highlightFactor);
        color.rgb += adjustment;
    }
    
    // Clamp the color to valid range
    color = clamp(color, half4(0.0), half4(1.0));
    
    // Write the result to the output texture
    outputTexture.write(color, gid);
}
