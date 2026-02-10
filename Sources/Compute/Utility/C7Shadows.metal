#include <metal_stdlib>
using namespace metal;

kernel void C7Shadows(texture2d<half, access::read> inputTexture [[texture(0)]],
                      texture2d<half, access::write> outputTexture [[texture(1)]],
                      constant float *shadowAmount [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    // Get the dimensions of the input texture
    uint2 dimensions = inputTexture.get_width() * uint2(1, 1);
    if (gid.x >= dimensions.x || gid.y >= dimensions.y) {
        return;
    }
    
    // Read the input pixel
    half4 color = inputTexture.read(gid);
    
    // Calculate luminance to determine shadow areas
    half luminance = dot(color.rgb, half3(0.2126, 0.7152, 0.0722));
    
    // Get the shadow adjustment amount
    half shadow = half(*shadowAmount);
    
    if (shadow > 0.0) {
        // Increase shadow areas (dark pixels)
        half shadowFactor = smoothstep(half(0.0), half(0.5), luminance);
        half adjustment = shadow * (half(1.0) - shadowFactor);
        color.rgb += adjustment;
    } else if (shadow < 0.0) {
        // Decrease shadow areas (dark pixels)
        half shadowFactor = smoothstep(half(0.0), half(0.5), luminance);
        half adjustment = shadow * shadowFactor;
        color.rgb += adjustment;
    }
    
    // Clamp the color to valid range
    color = clamp(color, half4(0.0), half4(1.0));
    
    // Write the result to the output texture
    outputTexture.write(color, gid);
}
