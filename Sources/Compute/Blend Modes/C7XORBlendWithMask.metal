#include <metal_stdlib>
using namespace metal;

kernel void C7XORBlendWithMask(texture2d<half, access::write> outputTexture [[texture(0)]],
                               texture2d<half, access::read> backgroundTexture [[texture(1)]],
                               texture2d<half, access::sample> foregroundTexture [[texture(2)]],
                               texture2d<half, access::sample> maskTexture [[texture(3)]],
                               constant float *intensity [[buffer(0)]],
                               uint2 grid [[thread_position_in_grid]]) {
    const half4 background = backgroundTexture.read(grid);
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    
    float width = float(outputTexture.get_width());
    float height = float(outputTexture.get_height());
    float2 uv = float2(float(grid.x) / width, float(grid.y) / height);
    
    const half4 foreground = foregroundTexture.sample(quadSampler, uv);
    const half4 mask = maskTexture.sample(quadSampler, uv);
    
    // XOR混合逻辑：当蒙版值为1时使用前景颜色，否则使用背景颜色
    half4 blended = mask.r > 0.5 ? foreground : background;
    
    const half4 output = mix(background, blended, half(*intensity));
    outputTexture.write(output, grid);
}
