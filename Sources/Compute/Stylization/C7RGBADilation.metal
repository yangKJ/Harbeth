// 由 Condy 维护。各通道独立最大值，零半径及负颜色不被改写。
#include <metal_stdlib>
using namespace metal;
kernel void C7RGBADilation(texture2d<float, access::write> outputTexture [[texture(0)]],
                           texture2d<float, access::read> inputTexture [[texture(1)]],
                           constant float &pixelRadius [[buffer(0)]],
                           constant float &vertical [[buffer(1)]],
                           constant float &halfOutput [[buffer(2)]],
                           uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const bool isVertical = vertical > 0.5f;
    const int2 maximum = int2(inputTexture.get_width()-1,inputTexture.get_height()-1);
    const int limit = isVertical ? maximum.y : maximum.x;
    const int radius = isfinite(pixelRadius) ? int(min(abs(pixelRadius),float(limit))) : 0;
    float4 value = inputTexture.read(grid);
    for (int i=-radius; i<=radius; i++) {
        const int2 p = clamp(int2(grid)+(isVertical ? int2(0,i) : int2(i,0)),int2(0),maximum);
        value = max(value,inputTexture.read(uint2(p)));
    }
    outputTexture.write(halfOutput > 0.5f ? float4(half4(value)) : value,grid);
}
