//
//  HostHUDOverlay.metal
//  Harbeth-iOS-Demo
//
//  Created by Condy on 2026/7/31.
//

#include <metal_stdlib>
using namespace metal;

kernel void harbethDemoHostHUDOverlay(
    texture2d<float, access::read> colorTexture [[texture(0)]],
    texture2d<float, access::read> luminanceTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    uint2 position [[thread_position_in_grid]])
{
    const uint width = outputTexture.get_width();
    const uint height = outputTexture.get_height();
    if (position.x >= width || position.y >= height) {
        return;
    }

    float4 color = colorTexture.read(position);
    const float2 uv = (float2(position) + 0.5) / float2(width, height);
    const uint2 meterSample = uint2(width / 2, height / 2);
    const float luminance = saturate(luminanceTexture.read(meterSample).r);

    const bool insidePanel = uv.x >= 0.05 && uv.x <= 0.50 && uv.y >= 0.06 && uv.y <= 0.26;
    if (insidePanel) {
        color.rgb = mix(color.rgb, float3(0.36, 0.28, 0.98), 0.72);
    }

    const bool insideTrack = uv.x >= 0.09 && uv.x <= 0.46 && uv.y >= 0.18 && uv.y <= 0.215;
    if (insideTrack) {
        const float progress = (uv.x - 0.09) / 0.37;
        color.rgb = progress <= luminance ? float3(1.0) : float3(0.13, 0.10, 0.32);
    }

    const bool panelBorder = insidePanel && (
        uv.x <= 0.055 || uv.x >= 0.495 || uv.y <= 0.066 || uv.y >= 0.254
    );
    if (panelBorder) {
        color.rgb = float3(1.0);
    }

    outputTexture.write(color, position);
}
