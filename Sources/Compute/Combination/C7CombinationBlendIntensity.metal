#include <metal_stdlib>
using namespace metal;

kernel void C7CombinationBlendIntensity(texture2d<half, access::write> outputTexture [[texture(0)]],
                                        texture2d<half, access::read> inputTexture [[texture(1)]],
                                        texture2d<half, access::read> processedTexture [[texture(2)]],
                                        constant float *intensity [[buffer(0)]],
                                        uint2 gid [[thread_position_in_grid]]) {
    uint2 dimensions = uint2(inputTexture.get_width(), inputTexture.get_height());
    if (gid.x >= dimensions.x || gid.y >= dimensions.y) {
        return;
    }

    half4 originalColor = inputTexture.read(gid);
    half4 processedColor = processedTexture.read(gid);
    half4 finalColor = mix(originalColor, processedColor, half(*intensity));
    outputTexture.write(finalColor, gid);
}
